//
//  Money.swift
//  smartbud
//
//  Decimal arithmetic for amounts. SwiftData persists Decimal as REAL, so
//  models keep `Double`; correctness comes from converting to Decimal at the
//  boundary and doing every sum in base 10.
//

import Foundation

enum Money {
    /// Largest single amount any entry path accepts (number pad, import,
    /// Shortcuts), so imported rows cannot bypass the on-screen cap.
    static let maxAmount: Double = 100_000_000

    /// Converts a stored amount to Decimal, rounded to cents first so the
    /// binary floating-point tail (12.299999… for 12.3) never enters a sum.
    static func cents(_ value: Double) -> Decimal {
        // `Decimal(Double.infinity)` traps; a corrupted or imported value
        // must not take the process down.
        guard value.isFinite else { return .zero }
        var source = Decimal(value)
        var result = Decimal()
        NSDecimalRound(&result, &source, 2, .plain)
        return result
    }

    /// Exact sum of a list of stored amounts.
    static func sum<S: Sequence>(_ values: S) -> Decimal where S.Element == Double {
        values.reduce(Decimal.zero) { $0 + cents($1) }
    }

    /// Fraction of `budget` already spent, clamped to finite values.
    ///
    /// A non-positive or non-finite budget counts as fully used as soon as
    /// anything has been spent, so callers can safely pass the result to
    /// `Int(round(_:))` — dividing by zero there would trap.
    static func spendFraction(_ spent: Double, of budget: Double) -> Double {
        guard budget > 0, budget.isFinite, spent.isFinite else {
            return spent.isFinite && spent > 0 ? 1 : 0
        }
        return spent / budget
    }

    /// Rounds to whole cents (half away from zero at the third decimal).
    static func rounded(_ value: Decimal) -> Decimal {
        var source = value
        var result = Decimal()
        NSDecimalRound(&result, &source, 2, .plain)
        return result
    }

    /// Double view of an accumulated Decimal — convert once, at the chart/UI
    /// boundary, never mid-accumulation.
    static func double(_ value: Decimal) -> Double {
        NSDecimalNumber(decimal: value).doubleValue
    }

    /// Currency string for display. Amounts render as a magnitude; pass
    /// `plus` to force a leading `+`/`-` (nil keeps the natural rendering).
    static func format(
        _ value: Double,
        currencyCode: String,
        showsCents: Bool = true,
        plus: Bool? = nil,
        locale: Locale
    ) -> String {
        format(cents(value), currencyCode: currencyCode,
               showsCents: showsCents, plus: plus, locale: locale)
    }

    static func format(
        _ value: Decimal,
        currencyCode: String,
        showsCents: Bool = true,
        plus: Bool? = nil,
        locale: Locale
    ) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        formatter.maximumFractionDigits = showsCents ? 2 : 0

        let magnitude = formatter.string(from: NSDecimalNumber(decimal: abs(value))) ?? "0"
        guard let plus else { return magnitude }
        return (plus ? "+" : "-") + magnitude
    }
}
