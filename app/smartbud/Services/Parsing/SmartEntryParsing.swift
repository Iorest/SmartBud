//
//  SmartEntryParsing.swift
//  smartbud
//
//  The three-layer smart-entry chain: deterministic rules, the user's own
//  confirmed history, then an optional user-supplied LLM. Everything in this
//  file is Foundation-only so the rules of the chain are testable on Linux —
//  Natural Language tagging, SwiftUI and the network client stay outside.
//
//  No layer writes to the ledger. Every result is a candidate the entry form
//  still has to confirm.
//

import Foundation

// MARK: - Candidate

enum ParseSource: String {
    case rule
    case history
    case llm
    case ocr
}

/// One parse candidate shown as a preview and copied into the form on confirm.
struct ParsedExpense: Equatable {
    var amount: Decimal
    var isIncome: Bool
    var merchant: String?
    /// Internal rule bucket ("餐饮"), resolved with `ExpenseTextParser.resolveCategory`.
    var categoryHint: String?
    /// Exact name of a user category, learned from history or returned by the LLM.
    var categoryName: String?
    var source: ParseSource

    init(
        amount: Decimal,
        isIncome: Bool,
        merchant: String? = nil,
        categoryHint: String? = nil,
        categoryName: String? = nil,
        source: ParseSource = .rule
    ) {
        self.amount = amount
        self.isIncome = isIncome
        self.merchant = merchant
        self.categoryHint = categoryHint
        self.categoryName = categoryName
        self.source = source
    }
}

// MARK: - Amount extraction

/// Amounts are always read from the user's phrase by this parser, never
/// computed by a model. Kept separate from `ExpenseTextParser` so the LLM
/// validator and the Linux tests use exactly the same rules.
enum ParsedAmount {
    private static let number = #"(\d[\d,]*(?:\.\d+)?)"#

    static func extract(from text: String) -> Decimal? {
        // Explicit "actually paid" labels win over prices, discounts and
        // dates mentioned earlier in the same phrase.
        let patterns = [
            "实付[:：]?\\s*" + number,
            "我付[:：]?\\s*" + number,
            "付了[:：]?\\s*" + number,
            "花了[:：]?\\s*" + number,
            "¥\\s*" + number,
            "£\\s*" + number,
            "￥\\s*" + number,
            number + "\\s*元",
            number + "\\s*块",
            "金额[:：]?\\s*" + number,
            "消费[:：]?\\s*" + number,
            "支付[:：]?\\s*" + number,
            "花费[:：]?\\s*" + number,
            "扣款[:：]?\\s*" + number
        ]
        for pattern in patterns {
            if let match = firstMatch(pattern, in: text),
               let value = decimal(match) {
                return value
            }
        }
        // `String.range(of:options:.regularExpression)` returns a wrong range
        // for Chinese phrases ("电影票两张 90" → "两"). NSRegularExpression
        // works on both Darwin and Linux, so use it for the final bare-number
        // fallback too. "满100减20 咖啡 40" means the last number is the
        // price actually paid.
        let candidates = candidates(in: text)
        if text.contains("满"), text.contains("减") {
            return candidates.last.flatMap(decimal)
        }
        return candidates.first.flatMap(decimal)
    }

    /// Distinct numbers left after dates, times and counters are removed.
    /// More than one means the phrase is ambiguous — no layer may guess.
    static func candidates(in text: String) -> [String] {
        let stripped = stripNoise(from: text)
        guard let regex = try? NSRegularExpression(pattern: number) else { return [] }
        let range = NSRange(stripped.startIndex..., in: stripped)
        var seen = Set<String>()
        var result: [String] = []
        for match in regex.matches(in: stripped, range: range) {
            guard let range = Range(match.range, in: stripped) else { continue }
            let value = String(stripped[range])
            if seen.insert(value).inserted { result.append(value) }
        }
        return result
    }

    static func decimal(_ raw: String) -> Decimal? {
        let cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: "")
        guard let value = Decimal(string: cleaned), value > 0, value <= Decimal(Money.maxAmount) else {
            return nil
        }
        return value
    }

    private static func firstMatch(_ pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              match.numberOfRanges > 1,
              let range = Range(match.range(at: 1), in: text) else { return nil }
        return String(text[range])
    }

    private static func stripNoise(from text: String) -> String {
        let patterns = [
            #"\d{4}[-/年]\d{1,2}[-/月]\d{1,2}日?"#,
            #"\d{1,2}月\d{1,2}[日号]"#,
            #"\d{1,2}[:：]\d{2}"#,
            #"\d+\s*(个|人|件|份|杯|次|张|斤|克|公斤|公里|小时|分钟|km|g|kg)"#,
            #"^\s*\d{1,2}[./-]\d{1,2}(?=\D|$)"#,      // 10/12, 10.25
            #"\b\d{1,2}号\b"#,                          // 25号
            #"\b(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\s+\d{1,2}\b"#,
            #"12306(?=\s*[,，]|购票)"#,                  // train booking code
            #"\b\d+\s+(?:coffees?|people|persons?|cups?|tickets?|items?)\b"#
        ]
        var result = text
        for pattern in patterns {
            result = result.replacingOccurrences(
                of: pattern, with: " ", options: .regularExpression
            )
        }
        return result
    }
}

// MARK: - History

/// One confirmed row from the user's ledger. Only the fields the learning
/// rule needs; SwiftData models never cross into this layer.
struct ParseHistoryEntry: Equatable {
    let merchantName: String
    let merchantKey: String
    let categoryName: String
    let isIncome: Bool
}

enum ParseHistory {
    /// Merchant mentioned in the phrase, matched against names the user has
    /// confirmed before. Longest name wins; ties break on the key so the
    /// result never depends on fetch or dictionary order.
    static func merchantKey(in text: String, entries: [ParseHistoryEntry]) -> String? {
        let lowered = text.lowercased()
        return entries
            .filter { $0.merchantName.count >= 2 && lowered.contains($0.merchantName.lowercased()) }
            .sorted { left, right in
                if left.merchantName.count != right.merchantName.count {
                    return left.merchantName.count > right.merchantName.count
                }
                return left.merchantKey < right.merchantKey
            }
            .first?.merchantKey
    }

    /// Majority category for a merchant and direction. A tie is not a
    /// majority: return nil rather than picking a category at random.
    static func category(for key: String, entries: [ParseHistoryEntry], isIncome: Bool) -> String? {
        var counts: [String: Int] = [:]
        for entry in entries where entry.merchantKey == key && entry.isIncome == isIncome {
            counts[entry.categoryName, default: 0] += 1
        }
        guard let best = counts.max(by: { $0.value < $1.value }),
              counts.values.filter({ $0 == best.value }).count == 1 else { return nil }
        return best.key
    }

    /// Applies history to a deterministic or LLM candidate. Rules and the
    /// model keep their amount and direction; only the category (and a
    /// missing merchant name) may be replaced by the user's own data.
    static func apply(
        to candidate: ParsedExpense,
        text: String,
        entries: [ParseHistoryEntry]
    ) -> ParsedExpense {
        guard entries.count >= 2,
              let key = merchantKey(in: text, entries: entries)
                ?? candidate.merchant.flatMap({ MerchantNormalizer.normalize($0)?.key }),
              let learned = category(for: key, entries: entries, isIncome: candidate.isIncome)
        else { return candidate }

        var updated = candidate
        if updated.merchant == nil {
            updated.merchant = entries.first(where: { $0.merchantKey == key })?.merchantName
        }
        updated.categoryName = learned
        updated.categoryHint = nil
        updated.source = .history
        return updated
    }
}

// MARK: - LLM candidate

/// The only thing the app asks the model for: a candidate, never arithmetic.
protocol LLMCandidateParsing {
    func parseCandidate(text: String, allowedCategories: [String]) async throws -> ParsedExpense
}

enum LLMCandidateError: Error, Equatable {
    case invalidJSON
    case invalidSchema
    case missingAmount
    case ambiguousAmount
    case amountNotInPhrase
    case unknownCategory
    case rejectedByFormValidation

    /// Localization key used by the sheet's readable fallback message.
    var localizationKey: String {
        switch self {
        case .invalidJSON, .invalidSchema: return SmartEntryKey.llmInvalidResponse
        case .missingAmount: return SmartEntryKey.llmMissingAmount
        case .ambiguousAmount: return SmartEntryKey.llmAmbiguousAmount
        case .amountNotInPhrase: return SmartEntryKey.llmAmountNotInPhrase
        case .unknownCategory: return SmartEntryKey.llmUnknownCategory
        case .rejectedByFormValidation: return SmartEntryKey.llmRejectedByValidation
        }
    }
}

enum LLMCandidateValidator {
    private struct Wire: Decodable {
        let amount: String
        let isIncome: Bool
        let merchant: String
        let category: String
    }

    /// The model may only copy one of the numbers already present in the
    /// phrase. It is never asked to add, subtract or convert anything.
    static func systemPrompt(allowedCategories: [String]) -> String {
        """
        You extract fields from one Chinese or English bookkeeping phrase. \
        Reply with one JSON object and nothing else. Keys: amount, isIncome, \
        merchant, category. "amount" must be the number copied verbatim from \
        the phrase — never compute, round or convert it. "isIncome" is true \
        only for salary, bonus or money received. "merchant" is the shop name \
        or an empty string. "category" must be exactly one of: \
        \(allowedCategories.joined(separator: " | ")). \
        If the phrase has several different amounts, reply with {"amount":""} \
        instead of choosing one.
        """
    }

    static func userPrompt(text: String) -> String {
        "Phrase: \(text)"
    }

    static func validate(
        _ response: String,
        originalText: String,
        allowedCategories: [String]
    ) throws -> ParsedExpense {
        guard let data = response.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data),
              let object = json as? [String: Any],
              Set(object.keys) == Set(["amount", "isIncome", "merchant", "category"])
        else { throw LLMCandidateError.invalidSchema }

        let wire: Wire
        do {
            wire = try JSONDecoder().decode(Wire.self, from: data)
        } catch {
            throw LLMCandidateError.invalidJSON
        }

        let candidates = ParsedAmount.candidates(in: originalText)
        guard !wire.amount.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw LLMCandidateError.missingAmount
        }
        guard candidates.count == 1 else { throw LLMCandidateError.ambiguousAmount }
        let supplied = wire.amount.trimmingCharacters(in: .whitespacesAndNewlines)
        guard supplied == candidates[0] else { throw LLMCandidateError.amountNotInPhrase }
        guard let amount = ParsedAmount.decimal(supplied) else { throw LLMCandidateError.missingAmount }

        let category = wire.category.trimmingCharacters(in: .whitespacesAndNewlines)
        guard allowedCategories.contains(category) else { throw LLMCandidateError.unknownCategory }

        let amountForValidation = NSDecimalNumber(decimal: amount).doubleValue
        guard TransactionValidation.error(
            amount: amountForValidation,
            hasCategory: true,
            requiresCategory: true,
            needsExchangeRate: false
        ) == nil else { throw LLMCandidateError.rejectedByFormValidation }

        let merchantName = wire.merchant.trimmingCharacters(in: .whitespacesAndNewlines)
        guard merchantName.count <= MerchantNormalizer.maxLength else {
            throw LLMCandidateError.invalidSchema
        }
        let merchant = MerchantNormalizer.normalize(merchantName.isEmpty ? nil : merchantName)
        return ParsedExpense(
            amount: amount,
            isIncome: wire.isIncome,
            merchant: merchant?.name ?? (merchantName.isEmpty ? nil : merchantName),
            categoryName: category,
            source: .llm
        )
    }
}

// MARK: - Chain

struct SmartParseOutcome: Equatable {
    var candidate: ParsedExpense?
    /// Localization key for the readable "fallback did not work" message.
    var failureKey: String?
}

struct SmartEntryParser {
    let llm: (any LLMCandidateParsing)?

    /// Rules win as-is (with history applied). Only a failed rule parse goes
    /// to history-assisted LLM extraction, and only when the caller has
    /// opted in and configured a service.
    func parse(
        text: String,
        rule: ParsedExpense?,
        history: [ParseHistoryEntry],
        allowedCategories: [String]
    ) async -> SmartParseOutcome {
        if let rule {
            return SmartParseOutcome(
                candidate: ParseHistory.apply(to: rule, text: text, entries: history)
            )
        }
        guard let llm else {
            return SmartParseOutcome(failureKey: SmartEntryKey.noAmount)
        }
        do {
            var candidate = try await llm.parseCandidate(
                text: text, allowedCategories: allowedCategories
            )
            candidate = ParseHistory.apply(to: candidate, text: text, entries: history)
            return SmartParseOutcome(candidate: candidate)
        } catch let error as LLMCandidateError {
            return SmartParseOutcome(failureKey: error.localizationKey)
        } catch {
            return SmartParseOutcome(failureKey: SmartEntryKey.llmUnavailable)
        }
    }
}
