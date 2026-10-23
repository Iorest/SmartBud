//
//  TransferFeeMigration.swift
//  smartbud
//
//  One-off repair for transfers recorded before the fee became an expense row.
//  Kept out of `TransferFeeLedger` so that type stays testable without the rate
//  store (the tests live in the test target, where the app singletons are not
//  compiled).
//

import Foundation
import SwiftData

@MainActor
extension TransferFeeLedger {

    /// Writes the missing fee rows. Idempotent: transfers that already have a
    /// row are left alone, and the total balance does not move — the fee used
    /// to be deducted by the transfer and is now deducted by the row.
    @discardableResult
    static func migrate(in context: ModelContext) -> Int {
        let transfers = (try? context.fetch(FetchDescriptor<TransferModel>())) ?? []
        guard transfers.contains(where: { $0.fee > 0 }) else { return 0 }

        // One pass over the existing fee rows instead of one fetch per
        // transfer: the ledger can hold thousands of rows.
        var recorded = Set(feeRows(in: context).compactMap(\.transferFeeOf))
        var created = 0
        for transfer in transfers where transfer.fee > 0 {
            guard !recorded.contains(transfer.id) else { continue }
            recordFee(for: transfer, in: context,
                      baseAmount: convertedFee(transfer))
            recorded.insert(transfer.id)
            created += 1
        }
        if created > 0 { try? context.save() }
        return created
    }

    private static func convertedFee(_ transfer: TransferModel) -> Double {
        CurrencyRateStore.shared.convertToBase(
            transfer.fee,
            from: transfer.source?.resolvedCurrencyCode ?? "")
    }
}
