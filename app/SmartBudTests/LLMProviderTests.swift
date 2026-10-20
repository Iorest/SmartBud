//
//  LLMProviderTests.swift
//  SmartBudTests
//
//  Endpoint and validation rules for the user-configurable LLM. A wrong URL
//  here silently breaks AI analysis, so every shape a user can paste is
//  covered.
//

import Testing
import Foundation

@Suite("LLMProvider")
struct LLMProviderTests {

    // MARK: - OpenAI-compatible endpoints

    @Test("Base URL with /v1 appends chat/completions")
    func openAIWithVersion() {
        let url = LLMProvider.deepSeek.endpoint(baseURL: "https://api.deepseek.com/v1")
        #expect(url?.absoluteString == "https://api.deepseek.com/v1/chat/completions")
    }

    @Test("Host-only base URL gets the standard v1 path")
    func openAIWithoutVersion() {
        let url = LLMProvider.openAI.endpoint(baseURL: "https://api.openai.com")
        #expect(url?.absoluteString == "https://api.openai.com/v1/chat/completions")
    }

    @Test("Trailing slashes are ignored")
    func trailingSlash() {
        let url = LLMProvider.moonshot.endpoint(baseURL: "https://api.moonshot.cn/v1///")
        #expect(url?.absoluteString == "https://api.moonshot.cn/v1/chat/completions")
    }

    @Test("A complete endpoint is left untouched")
    func completeOpenAIPath() {
        let url = LLMProvider.custom.endpoint(baseURL: "https://gateway.example.com/v1/chat/completions")
        #expect(url?.absoluteString == "https://gateway.example.com/v1/chat/completions")
    }

    @Test("Local Ollama keeps http and needs no key")
    func ollamaLocal() {
        let url = LLMProvider.ollama.endpoint(baseURL: "http://localhost:11434/v1")
        #expect(url?.absoluteString == "http://localhost:11434/v1/chat/completions")
        #expect(LLMProvider.ollama.requiresAPIKey == false)
        #expect(LLMProvider.ollama.isConfigured(baseURL: "http://localhost:11434/v1", model: "qwen2.5:7b", apiKey: ""))
    }

    // MARK: - Anthropic endpoints

    @Test("Anthropic base URL resolves to v1/messages")
    func anthropicBase() {
        let url = LLMProvider.anthropic.endpoint(baseURL: "https://api.anthropic.com")
        #expect(url?.absoluteString == "https://api.anthropic.com/v1/messages")
    }

    @Test("Anthropic base ending in /v1 only appends messages")
    func anthropicVersioned() {
        let url = LLMProvider.anthropic.endpoint(baseURL: "https://api.anthropic.com/v1")
        #expect(url?.absoluteString == "https://api.anthropic.com/v1/messages")
    }

    @Test("Anthropic dialect is distinct from OpenAI")
    func anthropicDialect() {
        if case .anthropic = LLMProvider.anthropic.dialect {} else {
            Issue.record("Anthropic must use the messages dialect")
        }
    }

    // MARK: - Validation

    @Test("Invalid URLs are rejected")
    func invalidURLs() {
        #expect(LLMProvider.openAI.endpoint(baseURL: "") == nil)
        #expect(LLMProvider.openAI.endpoint(baseURL: "   ") == nil)
        #expect(LLMProvider.openAI.endpoint(baseURL: "ftp://example.com") == nil)
        #expect(LLMProvider.openAI.endpoint(baseURL: "not a url") == nil)
    }

    @Test("Remote providers require an API key")
    func remoteRequiresKey() {
        #expect(LLMProvider.openAI.isConfigured(baseURL: "https://api.openai.com/v1", model: "gpt-4o-mini", apiKey: "") == false)
        #expect(LLMProvider.openAI.isConfigured(baseURL: "https://api.openai.com/v1", model: "gpt-4o-mini", apiKey: "sk-test"))
        #expect(LLMProvider.openAI.isConfigured(baseURL: "", model: "gpt-4o-mini", apiKey: "sk-test") == false)
        #expect(LLMProvider.openAI.isConfigured(baseURL: "https://api.openai.com/v1", model: " ", apiKey: "sk-test") == false)
    }

    @Test("Custom endpoints keep an optional key field")
    func customKeyField() {
        #expect(LLMProvider.custom.showsAPIKeyField)
        #expect(LLMProvider.custom.requiresAPIKey == false)
        #expect(LLMProvider.custom.isConfigured(baseURL: "https://gateway.example.com/v1", model: "qwen", apiKey: ""))
        #expect(LLMProvider.ollama.showsAPIKeyField == false)
        #expect(LLMProvider.anthropic.showsAPIKeyField)
    }

    @Test("Inference recognises known hosts")
    func inference() {
        #expect(LLMProvider.inferred(fromBaseURL: "https://api.deepseek.com/v1") == .deepSeek)
        #expect(LLMProvider.inferred(fromBaseURL: "https://openrouter.ai/api/v1") == .openRouter)
        #expect(LLMProvider.inferred(fromBaseURL: "https://api.anthropic.com") == .anthropic)
        #expect(LLMProvider.inferred(fromBaseURL: "http://127.0.0.1:11434/v1") == .ollama)
        #expect(LLMProvider.inferred(fromBaseURL: "https://gateway.example.com/v1") == .custom)
    }
}
