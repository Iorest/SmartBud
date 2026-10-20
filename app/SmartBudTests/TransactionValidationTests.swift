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

    @Test("Only the category-related errors shake the field")
    func fieldHighlight() {
        #expect(TransactionValidationError.incompleteEntry.highlightsFields)
        #expect(TransactionValidationError.missingCategory.highlightsFields)
        #expect(!TransactionValidationError.missingAmount.highlightsFields)
    }

    @Test("Each error carries a distinct message and icon")
    func distinctMessages() {
        let all: [TransactionValidationError] = [.incompleteEntry, .missingAmount, .missingCategory]
        #expect(Set(all.map(\.toastTitleKey)).count == all.count)
        #expect(Set(all.map(\.systemImage)).count == all.count)
    }
}
