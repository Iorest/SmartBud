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
    /// Converts a stored amount to Decimal, rounded to cents first so the
    /// binary floating-point tail (12.299999… for 12.3) never enters a sum.
    static func cents(_ value: Double) -> Decimal {
        var source = Decimal(value)
        var result = Decimal()
        NSDecimalRound(&result, &source, 2, .plain)
        return result
    }

    /// Exact sum of a list of stored amounts.
    static func sum<S: Sequence>(_ values: S) -> Decimal where S.Element == Double {
        values.reduce(Decimal.zero) { $0 + cents($1) }
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
}
