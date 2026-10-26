//
//  LLMClient.swift
//  smartbud
//
//  Minimal client for an OpenAI-compatible or Anthropic-compatible endpoint.
//  The user supplies provider + baseURL + model + API key in Settings; the
//  key lives in the Keychain. Only aggregate figures leave the device —
//  never per-transaction detail.
//

import Foundation

// MARK: - Configuration

struct LLMConfig: Equatable {
    var provider: LLMProvider = .openAI
    var baseURL: String = ""
    var model: String = ""
    var apiKey: String = ""

    static let providerKey = "llmProvider"
    static let baseURLKey = "llmBaseURL"
    static let modelKey = "llmModel"
    private static let apiKeyAccount = "apiKey"

    static func load() -> LLMConfig {
        let defaults = UserDefaults.appGroup
        let baseURL = defaults.string(forKey: baseURLKey) ?? ""
        let provider: LLMProvider
        if let raw = defaults.string(forKey: providerKey), let saved = LLMProvider(rawValue: raw) {
            provider = saved
        } else if baseURL.trimmingCharacters(in: .whitespaces).isEmpty {
            provider = .openAI
        } else {
            // Configs written before the provider existed.
            provider = LLMProvider.inferred(fromBaseURL: baseURL)
        }
        return LLMConfig(
            provider: provider,
            baseURL: baseURL,
            model: defaults.string(forKey: modelKey) ?? "",
            apiKey: KeychainStore.get(forKey: apiKeyAccount) ?? ""
        )
    }

    /// Removes the stored API key. Used by "erase all data": the ledger and
    /// the CloudKit zone were wiped, but the key used to survive an uninstall
    /// and reappear in Settings.
    static func clearStoredKey() {
        KeychainStore.delete(forKey: apiKeyAccount)
    }

    func save() {
        let defaults = UserDefaults.appGroup
        defaults.set(provider.rawValue, forKey: Self.providerKey)
        defaults.set(baseURL.trimmingCharacters(in: .whitespacesAndNewlines), forKey: Self.baseURLKey)
        defaults.set(model.trimmingCharacters(in: .whitespacesAndNewlines), forKey: Self.modelKey)
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if key.isEmpty {
            KeychainStore.delete(forKey: Self.apiKeyAccount)
        } else {
            KeychainStore.set(key, forKey: Self.apiKeyAccount)
        }
    }

    var isConfigured: Bool {
        provider.isConfigured(baseURL: baseURL, model: model, apiKey: apiKey)
    }
}

// MARK: - Aggregate payload

/// Everything the model sees. Amounts are pre-formatted strings so the model
/// never does arithmetic (keeps the numbers trustworthy).
struct LedgerSummary: Codable {
    struct CategoryTotal: Codable {
        let name: String
        let amount: String
        let share: String
    }

    let period: String
    let currency: String
    let totalIncome: String
    let totalSpent: String
    let net: String
    let topCategories: [CategoryTotal]
    /// Expenses the user will be paid back for. They are excluded from
    /// `totalSpent`, so the analyst has to know they exist to explain why the
    /// card is lower than the bank statement.
    let pendingReimbursement: String?
    let language: String
}

// MARK: - Client

struct LLMClient {
    let config: LLMConfig

    enum Failure: LocalizedError {
        case notConfigured
        case invalidURL
        case unauthorized
        case notFound
        case rateLimited
        case server(Int)
        case http(Int, String)
        case emptyResponse
        case unexpectedResponse
        case timeout
        case network

        var errorDescription: String? {
            switch self {
            case .notConfigured:
                return String.appLocalized("AI 未配置，请先在设置中填写服务地址、模型和 API Key。")
            case .invalidURL:
                return String.appLocalized("服务地址无效。")
            case .unauthorized:
                return String.appLocalized("API Key 无效或没有权限，请检查后重试。")
            case .notFound:
                return String.appLocalized("服务地址或模型不存在，请检查服务地址与模型名称。")
            case .rateLimited:
                return String.appLocalized("请求过于频繁或额度不足，请稍后再试。")
            case .server(let status):
                return String.appLocalized("服务端暂时不可用，请稍后再试。") + " (HTTP \(status))"
            case .http(let status, let body):
                return "HTTP \(status): \(body.prefix(200))"
            case .emptyResponse:
                return String.appLocalized("服务未返回内容。")
            case .unexpectedResponse:
                return String.appLocalized("服务返回的内容无法解析，请检查服务地址与模型名称。")
            case .timeout:
                return String.appLocalized("连接超时，请检查网络或服务地址。")
            case .network:
                // URLError.localizedDescription follows the system language,
                // which would mix languages into the in-app UI.
                return String.appLocalized("无法连接服务器，请检查服务地址或网络。")
            }
        }
    }

    /// One non-streaming chat completion.
    func complete(system: String, user: String) async throws -> String {
        guard config.isConfigured else { throw Failure.notConfigured }

        let request = try makeRequest(system: system, user: user)
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch let error as URLError {
            // A dismissed sheet cancels the task; that is not a network error.
            if error.code == .cancelled { throw CancellationError() }
            throw error.code == .timedOut ? Failure.timeout : Failure.network
        }

        guard let http = response as? HTTPURLResponse else { throw Failure.emptyResponse }
        guard (200..<300).contains(http.statusCode) else {
            throw Self.failure(status: http.statusCode, data: data)
        }

        let content: String?
        do {
            switch config.provider.dialect {
            case .openAI:
                content = try JSONDecoder().decode(OpenAIChatResponse.self, from: data)
                    .choices.first?.message.content
            case .anthropic:
                content = try JSONDecoder().decode(AnthropicMessageResponse.self, from: data)
                    .content.first { $0.type == "text" }?.text
            }
        } catch is DecodingError {
            // A gateway login page or a provider-specific error body used to
            // surface as the English toolchain message.
            throw Failure.unexpectedResponse
        }

        guard let text = content?.trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty else {
            throw Failure.emptyResponse
        }
        return text
    }

    private func makeRequest(system: String, user: String) throws -> URLRequest {
        guard let url = config.provider.endpoint(baseURL: config.baseURL) else {
            throw Failure.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 45
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let key = config.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let model = config.model.trimmingCharacters(in: .whitespacesAndNewlines)

        let body: [String: Any]
        switch config.provider.dialect {
        case .openAI:
            if !key.isEmpty {
                request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
            }
            // No temperature: OpenAI's reasoning models reject non-default
            // values, and it adds nothing to a summarisation task.
            body = [
                "model": model,
                "messages": [
                    ["role": "system", "content": system],
                    ["role": "user", "content": user]
                ]
            ]
        case .anthropic:
            request.setValue(key, forHTTPHeaderField: "x-api-key")
            request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
            // Anthropic takes the system prompt as a top-level field and
            // requires max_tokens.
            body = [
                "model": model,
                "max_tokens": 1024,
                "system": system,
                "messages": [
                    ["role": "user", "content": user]
                ]
            ]
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }

    private static func failure(status: Int, data: Data) -> Failure {
        let body = String(data: data, encoding: .utf8) ?? ""
        switch status {
        case 401, 403: return .unauthorized
        case 404: return .notFound
        case 429: return .rateLimited
        case 500...599: return .server(status)
        default: return .http(status, body)
        }
    }

    /// Analyze aggregated ledger figures and return localized prose.
    func analyze(_ summary: LedgerSummary) async throws -> String {
        let system = """
        You are a careful personal-finance analyst. You receive aggregated \
        ledger figures as JSON (already formatted strings; do not recompute). \
        Reply in the language given by the "language" field. Give 3-5 short, \
        concrete observations: spending pattern, the largest category trend, \
        and one actionable suggestion. "pendingReimbursement" is money the \
        user expects back and is already excluded from "totalSpent"; mention \
        it only when present. No preamble, no markdown headings, no invented \
        numbers beyond the JSON.
        """
        let json = String(data: try JSONEncoder().encode(summary), encoding: .utf8) ?? "{}"
        return try await complete(system: system, user: json)
    }

    /// Verifies URL + key + model with the smallest possible request.
    func testConnection() async throws -> String {
        try await complete(system: "Reply with OK.", user: "ping")
    }
}

// MARK: - Provider response shapes

private struct OpenAIChatMessage: Decodable {
    let content: String?
}

private struct OpenAIChatChoice: Decodable {
    let message: OpenAIChatMessage
}

private struct OpenAIChatResponse: Decodable {
    let choices: [OpenAIChatChoice]
}

private struct AnthropicMessageResponse: Decodable {
    struct Block: Decodable {
        let type: String
        let text: String?
    }
    let content: [Block]
}
