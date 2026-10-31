//
//  MerchantSummary.swift
//  smartbud
//
//  Merchant dimension of the insights screen: spend grouped by
//  `TransactionModel.merchantKey`. Kept out of `InsightsViewModel` (which
//  needs the repository) so the grouping rules can be tested on plain model
//  objects.
//

import Foundation

/// One row of the merchant breakdown.
struct MerchantSlice: Hashable, Identifiable {
    /// `TransactionModel.merchantKey` — the grouping key, not a UUID.
    let id: String
    let name: String
    let amount: Double
    let percent: Double
    let transactionCount: Int
}

enum MerchantSummary {
    /// How many shops the card shows before it stops being readable.
    static let defaultLimit = 6

    /// Spend by merchant, largest first. `transactions` is expected to be the
    /// period already selected by the caller — this only groups.
    static func breakdown(
        of transactions: [TransactionModel],
        limit: Int = defaultLimit
    ) -> [MerchantSlice] {
        var amounts = [String: Decimal]()
        var counts = [String: Int]()
        // The spelling shown for a key comes from its largest row: rows written
        // by the migrator and by entry can differ in case ("Starbucks" vs
        // "starbucks"), and the biggest one is the one the user recognises.
        var largest = [String: (amount: Decimal, name: String)]()

        for txn in transactions where txn.countsAsSpend {
            guard let key = txn.merchantKey else { continue }
            let amount = Money.cents(txn.wrappedBaseAmount)
            amounts[key, default: 0] += amount
            counts[key, default: 0] += 1
            let name = txn.merchant ?? key
            if amount > (largest[key]?.amount ?? 0) {
                largest[key] = (amount, name)
            }
        }

        let total = amounts.values.reduce(Decimal.zero, +)
        guard total > 0 else { return [] }

        let slices: [MerchantSlice] = amounts.compactMap { (key, amount) in
            guard let entry = largest[key] else { return nil }
            return MerchantSlice(
                id: key,
                name: entry.name,
                amount: Money.double(amount),
                percent: min(1, Money.double(amount / total)),
                transactionCount: counts[key] ?? 0
            )
        }
        return slices.sorted { $0.amount > $1.amount }.prefix(max(0, limit)).map { $0 }
    }
}
