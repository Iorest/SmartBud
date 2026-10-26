//
//  SubscriptionError.swift
//  smartbud
//
//  StoreKit failures mapped to on-brand, localised copy.
//

import Foundation

// MARK: - Errors

enum SubscriptionError: Error, Identifiable, Equatable {
    case loadProductsFailed(Error)
    case purchaseFailed(Error)
    case purchasePending
    case restoreFailed(Error)

    var id: String {
        switch self {
        case .loadProductsFailed: "loadProductsFailed"
        case .purchaseFailed:     "purchaseFailed"
        case .purchasePending:    "purchasePending"
        case .restoreFailed:      "restoreFailed"
        }
    }

    var errorDescription: String? {
        // StoreKit surfaces its own `localizedDescription`, which follows the
        // device language and reads like a developer message. These alerts
        // use on-brand copy in the in-app language instead.
        switch self {
        case .loadProductsFailed:
            String.appLocalized(SettingsKey.proErrorLoad)
        case .purchaseFailed:
            String.appLocalized(SettingsKey.proErrorPurchase)
        case .restoreFailed:
            String.appLocalized(SettingsKey.proErrorRestore)
        case .purchasePending:
            String.appLocalized("settings.pro.error.pending")
        }
    }

    // Compare on the case label only — wrapped `Error`s aren't
    // `Equatable`, and two errors of the same kind are equivalent for
    // the `onChange(of: subscription.lastError)` deduplication in the
    // Pro view.
    static func == (lhs: SubscriptionError, rhs: SubscriptionError) -> Bool {
        lhs.id == rhs.id
    }
}
