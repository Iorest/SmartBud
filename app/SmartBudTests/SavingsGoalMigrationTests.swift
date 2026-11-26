//
//  SavingsGoalMigrationTests.swift
//  SmartBudTests
//
//  Old databases have no `savingsGoalsJSON`, so a goal migration must be a
//  no-op: no crash, no rows, no change to balances or spend. The JSON backup
//  must also carry goals through export → import without duplicating them.
//

import Testing
import Foundation
import SwiftData

@MainActor
@Suite("Savings goal migration and backup")
struct SavingsGoalMigrationTests {

    private let fixture: ImportFixture

    init() throws {
        fixture = try ImportFixture()
    }

    private func sampleGoal() -> SavingsGoalModel {
        var goal = SavingsGoalModel()
        goal.bookID = BookModel.defaultID
        goal.name = "Down payment"
        goal.mode = .fixedAmount
        goal.amountPerPeriod = 500
        goal.periods = 12
        goal.periodMonths = 1
        goal.savedAmount = 1_500
        goal.icon = "house"
        return goal
    }

    @Test("An old library has no goals and stays that way without a backfill")
    func oldLibraryNeedsNoBackfill() throws {
        let book = BookModel(name: BookModel.defaultName)
        book.id = BookModel.defaultID
        book.savingsGoalsJSON = nil
        fixture.context.insert(book)

        #expect(SavingsGoalStore.all(in: fixture.context).isEmpty)
        #expect(SavingsGoalStore.allAcrossBooks(in: fixture.context).isEmpty)
        #expect(try fixture.context.fetch(FetchDescriptor<TransactionModel>()).isEmpty)
    }

    @Test("Adding a goal changes neither the account balance nor the spend")
    func goalDoesNotMoveMoney() throws {
        let book = BookModel(name: BookModel.defaultName)
        book.id = BookModel.defaultID
        fixture.context.insert(book)
        let account = AccountModel(name: "Savings", emoji: "🏦", colour: "#000000",
                                   kind: 0, currencyCode: "CNY", openingBalance: 10_000)
        fixture.context.insert(account)
        try fixture.context.save()

        SavingsGoalStore.upsert(sampleGoal(), in: fixture.context)
        try fixture.context.save()

        let rows = try fixture.context.fetch(FetchDescriptor<TransactionModel>())
        #expect(rows.isEmpty)
        #expect(AccountBalance.current(
            opening: account.openingBalance, transactions: [],
            transfersIn: 0, transfersOut: 0) == 10_000)
        #expect(SavingsGoalStore.all(in: fixture.context).count == 1)
    }

    @Test("A goal survives export to backup and import into an empty store")
    func backupRoundTrip() throws {
        let original = sampleGoal()
        // Go through the real on-disk shape, not just the DTO: encode the
        // payload and read it back with the same decoder the import UI uses.
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let fileData = try encoder.encode(
            fixture.payload(savingsGoals: [ExportSchema.SavingsGoalDTO(model: original)]))
        let file = try DataImporter.decode(fileData)
        let summary = try DataImporter.apply(file, context: fixture.context)
        #expect(summary.savingsGoals == 1)
        let restored = SavingsGoalStore.allAcrossBooks(in: fixture.context)
        #expect(restored.count == 1)
        #expect(restored.first?.name == original.name)
        #expect(restored.first?.effectiveTarget == original.effectiveTarget)
        #expect(restored.first?.icon == original.icon)
        #expect(restored.first?.mode == original.mode)
        #expect(restored.first?.savedAmount == original.savedAmount)
    }

    @Test("Restoring the same backup twice does not duplicate goals")
    func repeatedImportIsIdempotent() throws {
        let payload = fixture.payload(
            savingsGoals: [ExportSchema.SavingsGoalDTO(model: sampleGoal())])
        _ = try DataImporter.apply(payload, context: fixture.context)
        let second = try DataImporter.apply(payload, context: fixture.context)

        #expect(SavingsGoalStore.allAcrossBooks(in: fixture.context).count == 1)
        #expect(second.savingsGoals == 0)
        #expect(second.skipped >= 1)
    }
}
