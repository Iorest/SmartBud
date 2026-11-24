//
//  ProAccess.swift
//  smartbud
//
//  What "Pro" actually unlocks, and the single rule that decides it.
//
//  The gates are built now but the launch promo (`limitedTimeFree`) keeps
//  everything open; flipping that flag in a release turns the same gates on
//  without touching feature code. `ProAccess.isUnlocked` is pure so the rule
//  is testable without StoreKit or UserDefaults.
//

import Foundation

enum ProFeature: String, CaseIterable, Identifiable {
    /// The AI analysis of the current period (bring-your-own LLM key).
    case aiAnalysis
    /// App icons other than the default one.
    case customAppIcons
    /// A custom time for the daily reminder (morning/evening stay free).
    case customReminderTime
    /// Recognise several receipt images in one preview-and-confirm pass.
    case batchRecognition

    var id: String { rawValue }

    /// Paywall title key, shared with the feature list on the Pro screen.
    var titleKey: String {
        switch self {
        case .aiAnalysis: return "Advanced Insights"
        case .customAppIcons: return "Exclusive Themes"
        case .customReminderTime: return "Smart Reminders"
        case .batchRecognition: return "Batch Recognition"
        }
    }
}

enum ProAccess {
    /// Pro when the launch promo is on, or when StoreKit reports a verified
    /// entitlement. No feature is permanently free-and-also-Pro; every gate
    /// goes through here.
    static func isUnlocked(_ feature: ProFeature, promo: Bool, entitled: Bool) -> Bool {
        switch feature {
        case .aiAnalysis, .customAppIcons, .customReminderTime, .batchRecognition:
            return promo || entitled
        }
    }
}
