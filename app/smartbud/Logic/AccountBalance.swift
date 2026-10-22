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
        transactions: [(amount: Double, income: Bool)],
        transfersIn: Double = 0,
        transfersOut: Double = 0
    ) -> Double {
        let spent = transactions.reduce(opening) { total, txn in
            total + (txn.income ? txn.amount : -txn.amount)
        }
        return spent + transfersIn - transfersOut
    }
}
