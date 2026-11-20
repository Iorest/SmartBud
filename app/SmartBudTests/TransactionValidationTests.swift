//
//  TransactionValidationTests.swift
//  SmartBudTests
//
//  The three refusal cases were inline `if/else if` chains in the view, so
//  nothing could catch a reordered branch silently turning a blank form into
//  a "missing category" message.
//

import Testing
import Foundation

@Suite("TransactionValidation")
struct TransactionValidationTests {

    @Test("Blank form is incomplete, not missing a field")
    func blankForm() {
        #expect(TransactionValidation.error(amount: 0, hasCategory: false) == .incompleteEntry)
    }

    @Test("Amount without category")
    func missingCategory() {
        #expect(TransactionValidation.error(amount: 12.5, hasCategory: false) == .missingCategory)
    }

    @Test("Category without amount")
    func missingAmount() {
        #expect(TransactionValidation.error(amount: 0, hasCategory: true) == .missingAmount)
    }

    @Test("Complete form passes")
    func complete() {
        #expect(TransactionValidation.error(amount: 12.5, hasCategory: true) == nil)
    }

    @Test("A row that is valid without a category can be saved without one")
    func categoryOptional() {
        // Balance adjustments and reimbursement repayments have no category
        // by design; requiring one made them impossible to edit.
        #expect(TransactionValidation.error(amount: 12.5, hasCategory: false,
                                            requiresCategory: false) == nil)
        #expect(TransactionValidation.error(amount: 0, hasCategory: false,
                                            requiresCategory: false) == .missingAmount)
    }

    @Test("Only the category-related errors shake the field")
    func fieldHighlight() {
        #expect(TransactionValidationError.incompleteEntry.highlightsFields)
        #expect(TransactionValidationError.missingCategory.highlightsFields)
        #expect(!TransactionValidationError.missingAmount.highlightsFields)
        #expect(!TransactionValidationError.missingExchangeRate.highlightsFields)
    }

    @Test("An account without a rate refuses the entry instead of guessing 1:1")
    func missingExchangeRate() {
        #expect(TransactionValidation.error(amount: 12.5, hasCategory: true,
                                            needsExchangeRate: true) == .missingExchangeRate)
        // A blank form is still a blank form: the user has to type something
        // before the rate matters.
        #expect(TransactionValidation.error(amount: 0, hasCategory: true,
                                            needsExchangeRate: true) == .missingAmount)
        // Without the flag nothing changes.
        #expect(TransactionValidation.error(amount: 12.5, hasCategory: true,
                                            needsExchangeRate: false) == nil)
    }

    @Test("Each error carries a distinct message and icon")
    func distinctMessages() {
        let all: [TransactionValidationError] = [.incompleteEntry, .missingAmount,
                                                .missingCategory, .missingExchangeRate]
        #expect(Set(all.map(\.toastTitleKey)).count == all.count)
        #expect(Set(all.map(\.systemImage)).count == all.count)
    }
}

/// The write gate and the converter share `usableRate`. A store could hold a
/// 0 / negative / non-finite rate from a legacy backup: `rate` ignores it and
/// returns 1, so the gate has to refuse that row too, not just a missing one.
@Suite("CurrencyRateGate")
struct CurrencyRateGateTests {
    private let base = "CNY"
    private let rates: [String: Double] = ["USD": 7.2, "JPY": 0, "EUR": .infinity]

    @Test("Base and empty currencies convert at 1 without a rate row")
    func baseNeedsNoRate() {
        #expect(!CurrencyConversion.needsRate(for: "CNY", base: base, rates: [:]))
        #expect(!CurrencyConversion.needsRate(for: "cny", base: base, rates: [:]))
        #expect(!CurrencyConversion.needsRate(for: "", base: base, rates: [:]))
        #expect(CurrencyConversion.rate(for: "CNY", base: base, rates: [:]) == 1)
    }

    @Test("A valid rate can be written")
    func validRate() {
        #expect(!CurrencyConversion.needsRate(for: "USD", base: base, rates: rates))
        #expect(CurrencyConversion.rate(for: "usd", base: base, rates: rates) == 7.2)
    }

    @Test("Missing or unusable stored rates refuse the write")
    func unusableRates() {
        #expect(CurrencyConversion.needsRate(for: "GBP", base: base, rates: rates))
        let badTables: [[String: Double]] = [
            ["USD": 0], ["USD": -1], ["USD": .infinity], ["USD": .nan]
        ]
        for bad in badTables {
            #expect(CurrencyConversion.needsRate(for: "USD", base: base, rates: bad))
            #expect(CurrencyConversion.rate(for: "USD", base: base, rates: bad)
                    == CurrencyConversion.fallbackRate)
        }
    }

    @Test("Every refused conversion is the 1:1 fallback")
    func gateMatchesConverter() {
        for code in ["USD", "GBP", "JPY", "EUR", "CNY", ""] {
            if CurrencyConversion.needsRate(for: code, base: base, rates: rates) {
                #expect(CurrencyConversion.rate(for: code, base: base, rates: rates)
                        == CurrencyConversion.fallbackRate)
            }
        }
        #expect(CurrencyConversion.needsRate(for: "JPY", base: base, rates: rates))
        #expect(CurrencyConversion.needsRate(for: "EUR", base: base, rates: rates))
    }
}
