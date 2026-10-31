//
//  MerchantMigrationTests.swift
//  SmartBudTests
//
//  Backfill runs on the first launch after the update, against a store that
//  was written by a build that never had a merchant field. It must fill what
//  it can, leave everything else alone, and be safe to run again — it runs on
//  every launch and after every import.
//

import Testing
import Foundation
import SwiftData

/// In-memory store the tests share; the container has to outlive the context.
@MainActor
struct MerchantStore {
    let container: ModelContainer
    var context: ModelContext { container.mainContext }

    init() throws {
        container = try ModelContainer(
            for: Schema([
                TransactionModel.self,
                CategoryModel.self,
                AccountModel.self,
                TransferModel.self,
                CurrencyRate.self,
                BudgetModel.self,
                MainBudgetModel.self,
                TemplateTransactionModel.self
            ]),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    /// A row as an old build wrote it: a note, no merchant fields.
    @discardableResult
    func legacyRow(note: String, amount: Double = 10, adjustment: Bool = false) -> TransactionModel {
        let txn = TransactionModel(
            note: note,
            baseAmount: amount,
            income: false,
            amount: amount,
            adjustment: adjustment
        )
        context.insert(txn)
        return txn
    }
}

@Suite("Merchant backfill")
@MainActor
struct MerchantMigrationTests {

    @Test("Old rows get a merchant and keep their data")
    func fillsLegacyRows() throws {
        let store = try MerchantStore()
        let meituan = store.legacyRow(note: "美团外卖 35", amount: 35)
        let lunch = store.legacyRow(note: "午饭 35", amount: 35)
        let coffee = store.legacyRow(note: "星巴克", amount: 22)
        let fee = store.legacyRow(note: "转账手续费", amount: 1)
        let correction = store.legacyRow(note: "Balance Adjustment", amount: 5, adjustment: true)
        try store.context.save()

        let filled = MerchantMigration.migrate(in: store.context)

        #expect(filled == 2)
        #expect(meituan.merchantKey == "美团")
        #expect(coffee.merchantKey == "星巴克")
        // A note that names no shop stays unlabelled rather than inventing one.
        #expect(lunch.merchantKey == nil)
        #expect(fee.merchantKey == nil)
        // Bookkeeping rows are not purchases.
        #expect(correction.merchantKey == nil)

        // Nothing was rewritten: same rows, same amounts.
        let rows = try store.context.fetch(FetchDescriptor<TransactionModel>())
        #expect(rows.count == 5)
        #expect(rows.map(\.amount).sorted() == [1, 5, 22, 35, 35])
    }

    @Test("Running the backfill twice changes nothing")
    func idempotent() throws {
        let store = try MerchantStore()
        store.legacyRow(note: "美团外卖 35")
        store.legacyRow(note: "午饭 35")
        try store.context.save()

        #expect(MerchantMigration.migrate(in: store.context) == 1)
        let rows = try store.context.fetch(FetchDescriptor<TransactionModel>())
        let keys = rows.map(\.merchantKey)
        let names = rows.map(\.merchant)

        #expect(MerchantMigration.migrate(in: store.context) == 0)
        #expect(rows.map(\.merchantKey) == keys)
        #expect(rows.map(\.merchant) == names)
        #expect(rows.count == 2)
    }

    @Test("A row that already has a key is never overwritten")
    func keepsExistingLabels() throws {
        let store = try MerchantStore()
        let labelled = store.legacyRow(note: "美团外卖 35")
        labelled.merchant = "楼下小店"
        labelled.merchantKey = "楼下小店"
        try store.context.save()

        #expect(MerchantMigration.migrate(in: store.context) == 0)
        #expect(labelled.merchant == "楼下小店")
        #expect(labelled.merchantKey == "楼下小店")
    }
}
