//
//  LLMClient.swift
//  smartbud
//
//  Minimal OpenAI-compatible client for ledger analysis. The user supplies
//  baseURL + model + API key in Settings; the key lives in the Keychain.
//  Only aggregate figures leave the device — never per-transaction detail.
//

import Foundation

// MARK: - Configuration

struct LLMConfig: Equatable {
    var baseURL: String = ""
    var model: String = ""
    var apiKey: String = ""

    static let baseURLKey = "llmBaseURL"
    static let modelKey = "llmModel"
    private static let apiKeyAccount = "apiKey"

    static func load() -> LLMConfig {
        let defaults = UserDefaults.appGroup
        return LLMConfig(
            baseURL: defaults.string(forKey: baseURLKey) ?? "",
            model: defaults.string(forKey: modelKey) ?? "",
            apiKey: KeychainStore.get(forKey: apiKeyAccount) ?? ""
        )
    }

    func save() {
        let defaults = UserDefaults.appGroup
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
        !baseURL.trimmingCharacters(in: .whitespaces).isEmpty
            && !model.trimmingCharacters(in: .whitespaces).isEmpty
            && !apiKey.trimmingCharacters(in: .whitespaces).isEmpty
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
    let language: String
}

// MARK: - Client

struct LLMClient {
    let config: LLMConfig

    enum Failure: LocalizedError {
        case notConfigured
        case invalidURL
        case http(Int, String)
        case emptyResponse

        var errorDescription: String? {
            switch self {
            case .notConfigured:
                return String.appLocalized("AI 未配置，请先在设置中填写服务地址、模型和 API Key。")
            case .invalidURL:
                return String.appLocalized("服务地址无效。")
            case .http(let status, let body):
                return "HTTP \(status): \(body.prefix(200))"
            case .emptyResponse:
                return String.appLocalized("服务未返回内容。")
            }
        }
    }

    private func endpoint() throws -> URL {
        var base = config.baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        while base.hasSuffix("/") { base.removeLast() }
        guard var url = URL(string: base) else { throw Failure.invalidURL }
        if !base.hasSuffix("/chat/completions") {
            url.append(path: "chat/completions")
        }
        return url
    }

    /// One non-streaming chat completion. `jsonMode` asks for a JSON object;
    /// endpoints that ignore `response_format` still work via the prompt.
    func complete(system: String, user: String, jsonMode: Bool = false) async throws -> String {
        guard config.isConfigured else { throw Failure.notConfigured }

        var request = URLRequest(url: try endpoint())
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")

        var body: [String: Any] = [
            "model": config.model,
            "temperature": 0.3,
            "messages": [
                ["role": "system", "content": system],
                ["role": "user", "content": user]
            ]
        ]
        if jsonMode { body["response_format"] = ["type": "json_object"] }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw Failure.emptyResponse }
        guard (200..<300).contains(http.statusCode) else {
            throw Failure.http(http.statusCode, String(data: data, encoding: .utf8) ?? "")
        }

        struct ChatResponse: Decodable {
            struct Choice: Decodable {
                struct Message: Decodable { let content: String? }
                let message: Message
            }
            let choices: [Choice]
        }
        let decoded = try JSONDecoder().decode(ChatResponse.self, from: data)
        guard let content = decoded.choices.first?.message.content,
              !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw Failure.emptyResponse
        }
        return content
    }

    /// Analyze aggregated ledger figures and return localized prose.
    func analyze(_ summary: LedgerSummary) async throws -> String {
        let system = """
        You are a careful personal-finance analyst. You receive aggregated \
        ledger figures as JSON (already formatted strings; do not recompute). \
        Reply in the language given by the "language" field. Give 3-5 short, \
        concrete observations: spending pattern, the largest category trend, \
        and one actionable suggestion. No preamble, no markdown headings, \
        no invented numbers beyond the JSON.
        """
        let json = String(data: try JSONEncoder().encode(summary), encoding: .utf8) ?? "{}"
        return try await complete(system: system, user: json)
    }

    /// Verifies URL + key + model with the smallest possible request.
    func testConnection() async throws -> String {
        try await complete(system: "Reply with OK.", user: "ping")
    }
}
