//
//  CurrencyRebase.swift
//  smartbud
//
//  Maths for "change the base currency without lying about history".
//
//  Amounts are stored twice: `amount` in the account's currency and
//  `baseAmount` frozen in whatever the base currency was at entry time. If the
//  base currency changes and we only rewrite the setting, every frozen
//  `baseAmount` is silently reinterpreted as the new currency. So a switch has
//  to convert the frozen amounts and the rate table in one step:
//
//    factor          = 1 / rate[newBase]        (old base → new base)
//    baseAmount_new  = baseAmount_old × factor
//    rate_new[X]     = rate_old[X] / rate[newBase]
//    the new base loses its row, the old base gains one
//
//  The plan is pure data so the arithmetic can be tested without SwiftData.
//

import Foundation

enum CurrencyRebase {

    struct Plan: Equatable {
        let oldBase: String
        let newBase: String
        /// Multiply every base-currency amount (transactions, budgets,
        /// templates) by this to move it into `newBase`.
        let factor: Double
        /// The whole replacement rate table, keyed by currency code, already
        /// expressed in `newBase`. The new base itself is not included.
        let rates: [String: Double]
    }

    enum Failure: Error, Equatable {
        case sameCurrency
        case missingRate(String)
    }

    /// - Parameters:
    ///   - rates: the current table, i.e. 1 unit of `code` = `rate` of `oldBase`.
    static func plan(
        from oldBase: String,
        to newBase: String,
        rates: [String: Double]
    ) -> Result<Plan, Failure> {
        let old = oldBase.uppercased()
        let new = newBase.uppercased()
        guard !new.isEmpty, old != new else { return .failure(.sameCurrency) }

        guard let anchor = rates[new], anchor.isFinite, anchor > 0 else {
            return .failure(.missingRate(new))
        }
        let factor = 1 / anchor

        var converted: [String: Double] = [:]
        for (code, rate) in rates {
            let upper = code.uppercased()
            guard upper != new, rate.isFinite, rate > 0 else { continue }
            let value = rate / anchor
            guard value.isFinite, value > 0 else { continue }
            converted[upper] = round(value)
        }
        // The old base is a foreign currency from now on.
        converted[old] = round(factor)
        converted[new] = nil

        return .success(Plan(oldBase: old, newBase: new,
                             factor: factor, rates: converted))
    }

    /// Six decimals is enough for display and keeps the table readable.
    static func round(_ value: Double) -> Double {
        guard value.isFinite else { return 0 }
        return (value * 1_000_000).rounded() / 1_000_000
    }
}
