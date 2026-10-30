//
//  TransactionSnapshot.swift
//  smartbud
//
//  Value copy of a transaction taken before a staged delete. Lives outside
//  `TransactionViewModel` so the restore path can be unit-tested without the
//  SwiftData-backed repository.
//

import Foundation

/// Everything needed to rebuild a transaction row *exactly*. Anything the
/// editor can write has to be captured here: a restore that silently dropped
/// the account, the frozen base amount or the claim flag would change the
/// account balance and the statistics behind the user's back.
struct TransactionSnapshot {
    let id: UUID
    let note: String
    let amount: Double
    let date: Date
    let category: CategoryModel?
    let account: AccountModel?
    let baseAmount: Double?
    let income: Bool
    let repeatType: Int
    let repeatCoefficient: Int
    let onceRecurring: Bool
    let discount: Double
    let reimbursable: Bool
    let reimbursedAt: Date?
    /// Links that decide how the row is counted: a repayment row is not
    /// income and a fee row belongs to its transfer. Dropping them on restore
    /// turned a neutral 88 back into 88 of earnings.
    let reimbursementOf: UUID?
    let transferFeeOf: UUID?
    let adjustment: Bool
    /// Merchant is a projection of the note, but a restore has to bring back
    /// exactly what was deleted — a note edited between delete and undo would
    /// otherwise re-derive a different key.
    let merchant: String?
    let merchantKey: String?

    @MainActor
    init(_ txn: TransactionModel) {
        id = txn.id
        note = txn.wrappedNote
        amount = txn.amount
        date = txn.wrappedDate
        category = txn.category
        account = txn.account
        baseAmount = txn.baseAmount
        income = txn.income
        repeatType = txn.recurringType
        repeatCoefficient = txn.recurringCoefficient
        onceRecurring = txn.onceRecurring
        discount = txn.discount
        reimbursable = txn.reimbursable
        reimbursedAt = txn.reimbursedAt
        reimbursementOf = txn.reimbursementOf
        transferFeeOf = txn.transferFeeOf
        adjustment = txn.adjustment
        merchant = txn.merchant
        merchantKey = txn.merchantKey
    }

    /// Rebuilds the row when `rollback()` could not bring the original object
    /// back (the context already committed the delete).
    @MainActor
    func makeTransaction() -> TransactionModel {
        let txn = TransactionModel(
            note: note,
            category: category,
            account: account,
            baseAmount: baseAmount,
            income: income,
            amount: amount,
            date: date,
            repeatType: repeatType,
            repeatCoefficient: repeatCoefficient,
            discount: discount,
            reimbursable: reimbursable,
            reimbursementOf: reimbursementOf,
            transferFeeOf: transferFeeOf,
            adjustment: adjustment,
            merchant: merchant,
            merchantKey: merchantKey
        )
        txn.id = id
        txn.onceRecurring = onceRecurring
        txn.reimbursedAt = reimbursedAt
        return txn
    }
}
