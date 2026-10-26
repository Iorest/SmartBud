//
//  LLMProvider.swift
//  smartbud
//
//  Provider metadata and endpoint rules for the optional ledger-analysis LLM.
//  Deliberately dependency-free (Foundation only) so the URL and validation
//  rules can be unit-tested without the app host or UserDefaults.
//

import Foundation

/// Request/response shape of a chat endpoint.
enum LLMDialect {
    /// `POST {base}/chat/completions`, `Authorization: Bearer <key>`.
    case openAI
    /// `POST {base}/v1/messages`, `x-api-key` + `anthropic-version`.
    case anthropic
}

enum LLMProvider: String, CaseIterable, Identifiable, Sendable {
    case openAI
    case deepSeek
    case moonshot
    case openRouter
    case ollama
    case anthropic
    case custom

    var id: String { rawValue }

    /// Brand names stay in English; only the custom option is localized.
    var titleKey: String {
        switch self {
        case .openAI: return "OpenAI"
        case .deepSeek: return "DeepSeek"
        case .moonshot: return "Moonshot (Kimi)"
        case .openRouter: return "OpenRouter"
        case .ollama: return "Ollama"
        case .anthropic: return "Anthropic Claude"
        case .custom: return "自定义 AI 服务"
        }
    }

    var dialect: LLMDialect {
        self == .anthropic ? .anthropic : .openAI
    }

    /// Base URL including the API version segment, matching what each
    /// provider documents. Users can still edit it after selecting.
    var defaultBaseURL: String {
        switch self {
        case .openAI: return "https://api.openai.com/v1"
        case .deepSeek: return "https://api.deepseek.com/v1"
        case .moonshot: return "https://api.moonshot.cn/v1"
        case .openRouter: return "https://openrouter.ai/api/v1"
        case .ollama: return "http://localhost:11434/v1"
        case .anthropic: return "https://api.anthropic.com"
        case .custom: return ""
        }
    }

    var defaultModel: String {
        switch self {
        case .openAI: return "gpt-4o-mini"
        case .deepSeek: return "deepseek-chat"
        case .moonshot: return "moonshot-v1-8k"
        case .openRouter: return "openai/gpt-4o-mini"
        case .ollama: return "qwen2.5:7b"
        case .anthropic: return "claude-sonnet-4-5"
        case .custom: return ""
        }
    }

    /// Local servers (Ollama, LM Studio, vLLM behind a gateway) usually have
    /// no key; requiring one would block them.
    var requiresAPIKey: Bool {
        switch self {
        case .ollama, .custom: return false
        default: return true
        }
    }

    /// Custom OpenAI-compatible gateways often do require a key, so keep the
    /// field visible there even though it is optional.
    var showsAPIKeyField: Bool {
        self != .ollama
    }

    var hintKey: String {
        switch self {
        case .openAI: return "使用 OpenAI Chat Completions 接口。"
        case .deepSeek: return "DeepSeek 开放平台，OpenAI 兼容接口。"
        case .moonshot: return "Moonshot / Kimi，OpenAI 兼容接口。"
        case .openRouter: return "OpenRouter 聚合多家模型，模型名形如 openai/gpt-4o-mini。"
        case .ollama: return "本机运行的 Ollama，无需 API Key。先执行 ollama serve。"
        case .anthropic: return "Anthropic Messages 接口，密钥通过 x-api-key 发送。"
        case .custom: return "任意 OpenAI 兼容服务（LM Studio、vLLM、企业网关等），需要鉴权时填写 API Key。"
        }
    }

    /// Best-effort mapping for configs saved before the provider was stored.
    static func inferred(fromBaseURL baseURL: String) -> LLMProvider {
        let lower = baseURL.lowercased()
        if lower.contains("anthropic") { return .anthropic }
        if lower.contains("deepseek") { return .deepSeek }
        if lower.contains("moonshot") || lower.contains("kimi") { return .moonshot }
        if lower.contains("openrouter") { return .openRouter }
        if lower.contains("localhost") || lower.contains("127.0.0.1") || lower.contains(":11434") {
            return .ollama
        }
        if lower.contains("openai.com") { return .openAI }
        return .custom
    }

    /// Resolves the actual chat endpoint. Accepts a base URL with or without
    /// the version segment, and leaves an already-complete path untouched.
    func endpoint(baseURL: String) -> URL? {
        var base = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        while base.hasSuffix("/") { base.removeLast() }
        guard !base.isEmpty,
              let url = URL(string: base),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else {
            return nil
        }
        // Plain HTTP is only acceptable on the machine itself. A remote
        // endpoint would send the API key and the ledger summary in clear
        // text, so reject it rather than letting ATS be the only guard.
        if scheme == "http", !Self.isLocalHost(url.host) {
            return nil
        }

        let path = url.path.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        switch dialect {
        case .openAI:
            if path.hasSuffix("chat/completions") { return url }
            if path.isEmpty { return url.appending(path: "v1/chat/completions") }
            return url.appending(path: "chat/completions")
        case .anthropic:
            if path.hasSuffix("messages") { return url }
            if path.hasSuffix("v1") { return url.appending(path: "messages") }
            return url.appending(path: "v1/messages")
        }
    }

    private static func isLocalHost(_ host: String?) -> Bool {
        let value = host?.lowercased() ?? ""
        return value == "localhost" || value == "127.0.0.1" || value == "::1"
            || value.hasSuffix(".local")
    }

    func isConfigured(baseURL: String, model: String, apiKey: String) -> Bool {
        let base = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = model.trimmingCharacters(in: .whitespacesAndNewlines)
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !base.isEmpty, !name.isEmpty else { return false }
        return requiresAPIKey ? !key.isEmpty : true
    }
}
