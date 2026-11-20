//
//  TransactionValidation.swift
//  smartbud
//
//  The three ways "save" can be refused, kept out of `TransactionView` so the
//  rules (and their wording) can be unit-tested.
//

import Foundation

enum TransactionValidationError: Equatable {
    /// Nothing entered at all — the form is still blank.
    case incompleteEntry
    case missingAmount
    case missingCategory
    /// The account's currency has no rate against the base currency, so the
    /// amount cannot be converted. Writing it anyway would freeze a 1:1 guess
    /// into `baseAmount` and quietly distort every total (`accounting-
    /// conventions.md` §6: 缺汇率时拒绝折算，不允许按 1:1 猜).
    case missingExchangeRate

    var toastTitleKey: String {
        switch self {
        case .incompleteEntry: return "Incomplete Entry"
        case .missingAmount: return "Missing Amount"
        case .missingCategory: return "Missing Category"
        case .missingExchangeRate: return "Exchange Rate Needed"
        }
    }

    var systemImage: String {
        switch self {
        case .incompleteEntry: return "questionmark.app"
        case .missingAmount: return "centsign.circle"
        case .missingCategory: return "tray"
        case .missingExchangeRate: return "arrow.left.arrow.right"
        }
    }

    /// The category pill shakes for the two states where the category is at
    /// fault; a missing amount or a missing rate only needs the toast — there
    /// is nothing wrong with the fields the user can see.
    var highlightsFields: Bool {
        switch self {
        case .incompleteEntry, .missingCategory: return true
        case .missingAmount, .missingExchangeRate: return false
        }
    }
}

enum TransactionValidation {
    /// `requiresCategory` is false for rows that are valid without one: balance
    /// adjustments and reimbursement repayments. They used to be impossible to
    /// edit — the form demanded a category and saving a category onto them
    /// breaks their identity.
    /// `needsExchangeRate` is true when the row's account currency has no rate
    /// against the base currency. It is checked after the amount because the
    /// rate is about converting a number that exists: a blank form still reads
    /// as a blank form.
    static func error(amount: Double, hasCategory: Bool,
                      requiresCategory: Bool = true,
                      needsExchangeRate: Bool = false) -> TransactionValidationError? {
        if amount == 0 && !hasCategory && requiresCategory { return .incompleteEntry }
        if amount == 0 { return .missingAmount }
        if needsExchangeRate { return .missingExchangeRate }
        if requiresCategory && !hasCategory { return .missingCategory }
        return nil
    }
}
