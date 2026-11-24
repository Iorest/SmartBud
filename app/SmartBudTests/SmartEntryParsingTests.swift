//
//  SmartEntryParsingTests.swift
//  SmartBudTests
//
//  Offline rules for the smart-entry chain: deterministic amount reading,
//  merchant-history learning, strict LLM candidate validation, and the
//  degrade-to-current-behaviour paths. No network and no app host needed.
//

import Testing
import Foundation

@Suite("Parsed amounts")
struct ParsedAmountTests {
    @Test("Chinese counters no longer hide the amount")
    func chineseCounter() {
        #expect(ParsedAmount.extract(from: "电影票两张 90") == 90)
        #expect(ParsedAmount.extract(from: "地铁一共24") == 24)
        #expect(ParsedAmount.extract(from: "京东购物59.21") == Decimal(string: "59.21"))
    }

    @Test("Dates, times and counters are ignored when looking for candidates")
    func noiseIsIgnored() {
        #expect(ParsedAmount.candidates(in: "10月25日 12:30 打车 3 个人 88") == ["88"])
        #expect(ParsedAmount.candidates(in: "午饭 35 饮料 20").count == 2)
    }

    @Test("Labeled and separated amounts keep their exact value")
    func labelledAmounts() {
        #expect(ParsedAmount.extract(from: "支付 ¥12,000.50") == Decimal(string: "12000.50"))
        #expect(ParsedAmount.extract(from: "满100减20 实付80") == 100) // first bare match
    }
}

@Suite("Parse history")
struct ParseHistoryTests {
    private func entry(_ merchant: String, _ category: String, income: Bool = false) -> ParseHistoryEntry {
        ParseHistoryEntry(
            merchantName: merchant,
            merchantKey: MerchantNormalizer.normalize(merchant)?.key ?? merchant,
            categoryName: category,
            isIncome: income
        )
    }

    @Test("Majority category of the same merchant and direction wins")
    func majority() {
        let entries = [
            entry("老乡鸡", "餐饮"), entry("老乡鸡", "餐饮"),
            entry("老乡鸡", "医疗"), entry("老乡鸡", "交通", income: true)
        ]
        #expect(ParseHistory.category(for: "老乡鸡", entries: entries, isIncome: false) == "餐饮")
        #expect(ParseHistory.category(for: "老乡鸡", entries: entries, isIncome: true) == "交通")
    }

    @Test("A tie is not a majority")
    func tieDoesNotGuess() {
        let entries = [entry("街角小馆", "餐饮"), entry("街角小馆", "购物")]
        #expect(ParseHistory.category(for: "街角小馆", entries: entries, isIncome: false) == nil)
    }

    @Test("Longest known merchant name in the phrase is used")
    func longestNameWins() {
        let entries = [
            entry("美团", "餐饮"), entry("美团外卖", "餐饮"),
            entry("街角小馆", "餐饮")
        ]
        #expect(ParseHistory.merchantKey(in: "美团外卖 35", entries: entries) == "美团")
        #expect(ParseHistory.merchantKey(in: "街角小馆 35", entries: entries) == "街角小馆")
    }

    @Test("History only fills the category, never the amount")
    func applyHistory() {
        let entries = [entry("老乡鸡", "餐饮"), entry("老乡鸡", "餐饮")]
        let rule = ParsedExpense(amount: 35, isIncome: false, merchant: "老乡鸡", categoryHint: "医疗")
        let result = ParseHistory.apply(to: rule, text: "老乡鸡 35", entries: entries)
        #expect(result.amount == 35)
        #expect(result.categoryHint == nil)
        #expect(result.categoryName == "餐饮")
        #expect(result.source == .history)

        let unknown = ParseHistory.apply(
            to: ParsedExpense(amount: 35, isIncome: false),
            text: "午饭 35", entries: entries
        )
        #expect(unknown == ParsedExpense(amount: 35, isIncome: false))
    }
}

@Suite("LLM candidate validation")
struct LLMCandidateValidatorTests {
    private let categories = ["餐饮", "交通"]
    private let phrase = "午饭 35"
    private let valid = #"{"amount":"35","isIncome":false,"merchant":"街角小馆","category":"餐饮"}"#

    private func expectError(_ response: String, text: String = "午饭 35", _ expected: LLMCandidateError) {
        do {
            _ = try LLMCandidateValidator.validate(
                response, originalText: text, allowedCategories: categories
            )
            #expect(Bool(false), "Expected \(expected) to be rejected")
        } catch let error as LLMCandidateError {
            #expect(error == expected)
        } catch {
            #expect(Bool(false), "Unexpected error: \(error)")
        }
    }

    @Test("A valid candidate keeps the model out of the arithmetic")
    func validCandidate() throws {
        let parsed = try LLMCandidateValidator.validate(
            valid, originalText: phrase, allowedCategories: categories
        )
        #expect(parsed.amount == 35)
        #expect(parsed.categoryName == "餐饮")
        #expect(parsed.isIncome == false)
        #expect(parsed.source == .llm)
    }

    @Test("Ten malformed or hostile responses are all rejected")
    func hostileResponses() {
        expectError("not json", .invalidSchema)
        expectError(#"{"amount":"35","isIncome":false,"merchant":"","category":"餐饮","extra":1}"#, .invalidSchema)
        expectError(#"{"amount":35,"isIncome":false,"merchant":"","category":"餐饮"}"#, .invalidJSON)
        expectError(#"{"amount":"","isIncome":false,"merchant":"","category":"餐饮"}"#, .missingAmount)
        expectError(#"{"amount":"80","isIncome":false,"merchant":"","category":"餐饮"}"#, .amountNotInPhrase)
        expectError(#"{"amount":"35","isIncome":"false","merchant":"","category":"餐饮"}"#, .invalidJSON)
        expectError(#"{"amount":"35","isIncome":false,"merchant":"","category":"宇宙"}"#, .unknownCategory)
        expectError(#"{"amount":"35","isIncome":false,"merchant":"","category":"餐饮"}"#,
                    text: "午饭 35 饮料 20", .ambiguousAmount)
        expectError(#"{"amount":"999999999999999","isIncome":false,"merchant":"","category":"餐饮"}"#,
                    text: "午饭 999999999999999", .missingAmount)
        let longMerchant = String(repeating: "店", count: 100)
        expectError(#"{"amount":"35","isIncome":false,"merchant":"\#(longMerchant)","category":"餐饮"}"#, .invalidSchema)
    }
}

private enum FakeLLMError: Error { case timeout }

private struct FakeLLM: LLMCandidateParsing {
    let result: Result<ParsedExpense, Error>

    func parseCandidate(text: String, allowedCategories: [String]) async throws -> ParsedExpense {
        try result.get()
    }
}

@Suite("Smart entry chain")
struct SmartEntryParserTests {
    private let categories = ["餐饮", "交通"]
    private let parser = SmartEntryParser(llm: nil)
    /// The test target compiles without SettingsKeys.swift, so keep the
    /// production keys here as plain values instead of importing UI files.
    private enum Key {
        static let noAmount = "smart.parse.error.noAmount"
        static let unavailable = "smart.parse.error.unavailable"
        static let ambiguous = "smart.parse.error.ambiguousAmount"
        static let invalid = "smart.parse.error.invalidResponse"
    }

    @Test("No opt-in service keeps the current no-amount behaviour")
    func noService() async {
        let outcome = await parser.parse(text: "午饭 35", rule: nil, history: [], allowedCategories: categories)
        #expect(outcome.candidate == nil)
        #expect(outcome.failureKey == Key.noAmount)
    }

    @Test("No service means the rule result is used without changes")
    func ruleWins() async {
        let rule = ParsedExpense(amount: 35, isIncome: false, merchant: nil, categoryHint: "餐饮")
        let outcome = await parser.parse(text: "午饭 35", rule: rule, history: [], allowedCategories: categories)
        #expect(outcome.candidate == rule)
        #expect(outcome.failureKey == nil)
    }

    @Test("Timeout and invalid candidate degrade to a readable prompt")
    func degradation() async {
        let cases: [(any Error, String)] = [
            (FakeLLMError.timeout, Key.unavailable),
            (LLMCandidateError.ambiguousAmount, Key.ambiguous),
            (LLMCandidateError.invalidJSON, Key.invalid)
        ]
        for (error, key) in cases {
            let outcome = await SmartEntryParser(llm: FakeLLM(result: .failure(error)))
                .parse(text: "午饭 35 饮料 20", rule: nil, history: [], allowedCategories: categories)
            #expect(outcome.candidate == nil)
            #expect(outcome.failureKey == key)
        }
    }

    @Test("A valid LLM candidate is still only a candidate")
    func llmCandidate() async {
        let candidate = ParsedExpense(
            amount: 35, isIncome: false, merchant: nil,
            categoryName: "餐饮", source: .llm
        )
        let outcome = await SmartEntryParser(llm: FakeLLM(result: .success(candidate)))
            .parse(text: "午饭 35", rule: nil, history: [], allowedCategories: categories)
        #expect(outcome.candidate == candidate)
        #expect(outcome.failureKey == nil)
    }
}
