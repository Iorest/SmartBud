//
//  MerchantMigration.swift
//  smartbud
//
//  One-off backfill for rows written before `merchant` / `merchantKey`
//  existed. Old rows only carry a note (and, for rows created from a receipt,
//  nothing at all), so the merchant is derived from the note with the same
//  rules entry uses.
//
//  Reentrant: it only fills rows whose `merchantKey` is still `nil`, so a
//  second run is a no-op and a row the user re-labelled is never overwritten.
//  Kept out of `MerchantNormalizer` so that type stays store-free.
//

import Foundation
import SwiftData

enum MerchantMigration {

    /// Fills `merchant` / `merchantKey` on every row that has none.
    /// Returns how many rows were written.
    ///
    /// Rows that are bookkeeping rather than purchases are skipped: a balance
    /// adjustment, a transfer fee or a reimbursement repayment has a machine
    /// generated note, and turning "转账手续费" into a merchant would put noise
    /// at the top of the stats.
    @MainActor
    @discardableResult
    static func migrate(
        in context: ModelContext,
        aliases: MerchantAliasTable = .default
    ) -> Int {
        let transactions = (try? context.fetch(FetchDescriptor<TransactionModel>())) ?? []
        var filled = 0
        for txn in transactions {
            // Already labelled (by entry, by a previous run, or by the user).
            guard txn.merchantKey == nil else { continue }
            guard !txn.adjustment, txn.transferFeeOf == nil, !txn.isReimbursementIncome else {
                continue
            }
            guard let merchant = MerchantNormalizer.derive(fromNote: txn.note, aliases: aliases)
            else { continue }
            txn.merchant = merchant.name
            txn.merchantKey = merchant.key
            filled += 1
        }
        if filled > 0 { try? context.save() }
        return filled
    }
}
