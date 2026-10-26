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
///
/// The code is a *stored* fact: `ContentViewModel.bootstrap()` pins it on the
/// first launch after install. Before that the key is absent (the value used to
/// come from the device locale alone), and any code reading the raw default
/// saw nothing — exports without a currency, widgets in another currency after
/// a region change, the importer unable to compare. `code` therefore still
/// falls back to the locale, and `pin` writes that fallback once.
enum AppBaseCurrency {
    static let storedKey = "currency"

    nonisolated static var code: String {
        code(in: .appGroup)
    }

    /// Same rule as `code`, exposed for the bootstrap and for tests that must
    /// not touch the shared app-group defaults.
    nonisolated static func code(in defaults: UserDefaults) -> String {
        let stored = defaults.string(forKey: storedKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !stored.isEmpty { return stored }
        let device = Locale.current.currency?.identifier ?? ""
        return device.isEmpty ? "USD" : device
    }

    /// Writes the effective code back so later reads (widgets, Shortcuts, the
    /// exporter, `AccountModel.resolvedCurrencyCode`) no longer depend on the
    /// device region. An existing value is never overwritten.
    @discardableResult
    nonisolated static func pin(in defaults: UserDefaults = .appGroup) -> String {
        let current = code(in: defaults)
        let raw = defaults.string(forKey: storedKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if raw != current {
            defaults.set(current, forKey: storedKey)
        }
        return current
    }
}
