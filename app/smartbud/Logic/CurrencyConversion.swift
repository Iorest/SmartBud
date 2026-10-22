//
//  CurrencyConversion.swift
//  smartbud
//
//  Multi-currency maths. Rates are expressed as "how many units of the base
//  currency one unit of `code` is worth", which keeps conversion a single
//  multiply and makes the base currency's rate trivially 1.
//

import Foundation

enum CurrencyConversion {
    /// Rate used when the user has not entered one for `code`. Treating an
    /// unknown currency as 1:1 keeps totals finite; the rates screen lists any
    /// currency still on the fallback so it can be corrected.
    static let fallbackRate: Double = 1

    static func rate(for code: String, base: String, rates: [String: Double]) -> Double {
        let target = code.uppercased()
        let baseCode = base.uppercased()
        if target.isEmpty || target == baseCode { return 1 }

        guard let value = rates[target], value > 0, value.isFinite else {
            return fallbackRate
        }
        return value
    }

    static func convert(
        _ amount: Double,
        from code: String,
        to base: String,
        rates: [String: Double]
    ) -> Double {
        guard amount.isFinite else { return 0 }
        return amount * rate(for: code, base: base, rates: rates)
    }

    /// Rounds to cents after conversion so stored base amounts never carry a
    /// floating-point tail into sums.
    static func convertRounded(
        _ amount: Double,
        from code: String,
        to base: String,
        rates: [String: Double]
    ) -> Double {
        let converted = convert(amount, from: code, to: base, rates: rates)
        return NSDecimalNumber(decimal: Money.cents(converted)).doubleValue
    }
}

/// Base currency without touching the rate store, so model extensions stay
/// nonisolated (the widget target reads amounts too).
enum AppBaseCurrency {
    nonisolated static var code: String {
        let stored = UserDefaults.appGroup.string(forKey: "currency") ?? ""
        return stored.isEmpty
            ? (Locale.current.currency?.identifier ?? "USD")
            : stored
    }
}
