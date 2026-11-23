//
//  AccountBalance.swift
//  smartbud
//
//  Pure balance maths, kept out of SwiftData so it can be unit tested
//  without a model container.
//

import Foundation

/// Pure balance maths, kept separate from SwiftData so it is testable without
/// a model container.
enum AccountBalance {
    static func current(
        opening: Double,
        transactions: [(amount: Double, income: Bool, isRefund: Bool)],
        transfersIn: Double = 0,
        transfersOut: Double = 0
    ) -> Double {
        // A refund is money coming back even though it is not income, so it
        // has to move the balance the other way from an expense.
        let spent = transactions.reduce(opening) { total, txn in
            total + (txn.income || txn.isRefund ? txn.amount : -txn.amount)
        }
        return spent + transfersIn - transfersOut
    }

    /// Signed row needed to move `current` to `target`, or nil when they
    /// already match to the cent. Kept here so the adjustment invariant can
    /// be tested without SwiftData or the rate store.
    static func adjustmentDelta(target: Double, current: Double) -> Double? {
        guard target.isFinite, current.isFinite else { return nil }
        let delta = Money.double(Money.cents(target) - Money.cents(current))
        return delta == 0 ? nil : delta
    }
}
