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
}
