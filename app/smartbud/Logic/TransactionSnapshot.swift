//
//  TransactionSnapshot.swift
//  smartbud
//
//  Value copy of a transaction taken before a staged delete. Lives outside
//  `TransactionViewModel` so the restore path can be unit-tested without the
//  SwiftData-backed repository.
//

import Foundation

/// Everything needed to rebuild a transaction row. Recurrence fields are part
/// of the snapshot so undo never turns a repeating transaction into a one-off.
struct TransactionSnapshot {
    let id: UUID
    let note: String
    let amount: Double
    let date: Date
    let category: CategoryModel?
    let income: Bool
    let repeatType: Int
    let repeatCoefficient: Int
    let onceRecurring: Bool

    @MainActor
    init(_ txn: TransactionModel) {
        id = txn.id
        note = txn.wrappedNote
        amount = txn.amount
        date = txn.wrappedDate
        category = txn.category
        income = txn.income
        repeatType = txn.recurringType
        repeatCoefficient = txn.recurringCoefficient
        onceRecurring = txn.onceRecurring
    }

    /// Rebuilds the row when `rollback()` could not bring the original object
    /// back (the context already committed the delete).
    @MainActor
    func makeTransaction() -> TransactionModel {
        let txn = TransactionModel(
            note: note,
            category: category,
            income: income,
            amount: amount,
            date: date,
            repeatType: repeatType,
            repeatCoefficient: repeatCoefficient
        )
        txn.id = id
        txn.onceRecurring = onceRecurring
        return txn
    }
}
