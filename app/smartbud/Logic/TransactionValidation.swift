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

    var toastTitleKey: String {
        switch self {
        case .incompleteEntry: return "Incomplete Entry"
        case .missingAmount: return "Missing Amount"
        case .missingCategory: return "Missing Category"
        }
    }

    var systemImage: String {
        switch self {
        case .incompleteEntry: return "questionmark.app"
        case .missingAmount: return "centsign.circle"
        case .missingCategory: return "tray"
        }
    }

    /// The category pill shakes for the two states where the category is at
    /// fault; a missing amount only needs the toast.
    var highlightsFields: Bool {
        switch self {
        case .incompleteEntry, .missingCategory: return true
        case .missingAmount: return false
        }
    }
}

enum TransactionValidation {
    static func error(amount: Double, hasCategory: Bool) -> TransactionValidationError? {
        if amount == 0 && !hasCategory { return .incompleteEntry }
        if amount == 0 { return .missingAmount }
        if !hasCategory { return .missingCategory }
        return nil
    }
}
