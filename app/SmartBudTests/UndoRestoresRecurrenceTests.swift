//
//  UndoRestoresRecurrenceTests.swift
//  SmartBudTests
//
//  Undo used to rebuild a deleted row from scratch, which silently dropped
//  `recurringType` / `recurringCoefficient` / `onceRecurring` — a repeating
//  transaction came back as a one-off. The snapshot is the fallback path, so
//  it is pinned here against a real (in-memory) SwiftData store.
//

import Testing
import Foundation
import SwiftData

@MainActor
@Suite("UndoRestoresRecurrence")
struct UndoRestoresRecurrenceTests {

    private func makeContext() throws -> ModelContext {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: TransactionModel.self,
            CategoryModel.self,
            BudgetModel.self,
            MainBudgetModel.self,
            TemplateTransactionModel.self,
            configurations: configuration
        )
        return ModelContext(container)
    }

    @Test("Restored row keeps its recurrence, identity and category")
    func restoresRecurrence() throws {
        let context = try makeContext()
        let category = CategoryModel(name: "Food", emoji: "🍔", colour: "#FDBC3B")
        context.insert(category)

        let original = TransactionModel(
            note: "Lunch",
            category: category,
            income: false,
            amount: 11,
            date: Date(timeIntervalSince1970: 1_700_000_000),
            repeatType: 3,
            repeatCoefficient: 2
        )
        context.insert(original)
        let snapshot = TransactionSnapshot(original)

        // What a staged delete does before the undo window closes.
        context.delete(original)
        try context.save()
        #expect(try context.fetch(FetchDescriptor<TransactionModel>()).isEmpty)

        // What the snapshot fallback does when rollback can't restore it.
        context.insert(snapshot.makeTransaction())
        try context.save()

        let rows = try context.fetch(FetchDescriptor<TransactionModel>())
        #expect(rows.count == 1)
        let restored = try #require(rows.first)

        #expect(restored.id == snapshot.id)
        #expect(restored.recurringType == 3)
        #expect(restored.recurringCoefficient == 2)
        #expect(restored.onceRecurring)
        #expect(restored.amount == 11)
        #expect(restored.wrappedNote == "Lunch")
        #expect(restored.category?.name == "Food")
    }

    @Test("A one-off row stays a one-off")
    func keepsOneOff() throws {
        let context = try makeContext()
        let original = TransactionModel(note: "Coffee", amount: 4.5,
                                        date: Date(timeIntervalSince1970: 1_700_000_000))
        context.insert(original)
        let snapshot = TransactionSnapshot(original)

        let restored = snapshot.makeTransaction()
        #expect(restored.recurringType == 0)
        #expect(restored.onceRecurring == false)
        context.insert(restored)
        try context.save()
    }
}
