//
//  ReimbursementLedger.swift
//  smartbud
//
//  The two rows of a reimbursement. A claim leaves the account and is kept out
//  of spend; settling it must put the money back, which means writing an income
//  row. That row is not earnings either — otherwise a neutral claim would show
//  up as profit. Keeping both halves here means the pairing (and its cleanup)
//  is one rule instead of five call sites.
//

import Foundation
import SwiftData

@MainActor
enum ReimbursementLedger {

    /// Income rows that settle a claim.
    static func repayments(in context: ModelContext) -> [TransactionModel] {
        let descriptor = FetchDescriptor<TransactionModel>(
            predicate: #Predicate { $0.reimbursementOf != nil })
        return (try? context.fetch(descriptor)) ?? []
    }

    static func repayment(for claim: TransactionModel, in context: ModelContext) -> TransactionModel? {
        repayments(in: context).first { $0.reimbursementOf == claim.id }
    }

    /// Marks the claim as paid back and writes the matching income row.
    @discardableResult
    static func settle(_ claim: TransactionModel, in context: ModelContext,
                       date: Date = .now) -> TransactionModel? {
        guard claim.reimbursable, !claim.income else { return nil }
        guard claim.reimbursedAt == nil else { return repayment(for: claim, in: context) }

        claim.reimbursedAt = date
        deleteRepayments(for: claim, in: context)

        let name = claim.wrappedNote.isEmpty ? claim.wrappedCategoryName : claim.wrappedNote
        let row = TransactionModel(
            note: String.appFormatted("Reimbursement · %@", name),
            category: nil,
            account: claim.account,
            baseAmount: claim.wrappedBaseAmount,
            income: true,
            amount: claim.amount,
            date: date,
            reimbursementOf: claim.id
        )
        context.insert(row)
        return row
    }

    /// Undoes a settlement: clears the date and removes the income row.
    static func unsettle(_ claim: TransactionModel, in context: ModelContext) {
        claim.reimbursedAt = nil
        deleteRepayments(for: claim, in: context)
    }

    /// Keeps the income row in step when the claim's amount or account changes.
    static func sync(_ claim: TransactionModel, in context: ModelContext) {
        guard let row = repayment(for: claim, in: context) else { return }
        row.amount = claim.amount
        row.baseAmount = claim.wrappedBaseAmount
        row.account = claim.account
    }

    /// The mirror image: editing the repayment row moves the claim with it, so
    /// the pair can never drift apart (a 88 expense paid back by a 120 income
    /// row would quietly create 32 of profit).
    static func syncClaim(from repayment: TransactionModel, in context: ModelContext) {
        guard let originalID = repayment.reimbursementOf else { return }
        let descriptor = FetchDescriptor<TransactionModel>(
            predicate: #Predicate { $0.id == originalID })
        guard let claim = (try? context.fetch(descriptor))?.first else { return }
        claim.amount = repayment.amount
        claim.baseAmount = repayment.wrappedBaseAmount
        claim.account = repayment.account
    }

    /// Deletes the income row(s) belonging to `claim`.
    static func deleteRepayments(for claim: TransactionModel, in context: ModelContext) {
        for row in repayments(in: context) where row.reimbursementOf == claim.id {
            context.delete(row)
        }
    }

    /// Called before deleting a row. A claim takes its repayment with it; a
    /// repayment puts its claim back into the pending list, because otherwise
    /// the claim would stay "paid" with no money behind it.
    static func prepareForDeletion(of txn: TransactionModel, in context: ModelContext) {
        if txn.reimbursable {
            deleteRepayments(for: txn, in: context)
        }
        guard let originalID = txn.reimbursementOf else { return }
        let descriptor = FetchDescriptor<TransactionModel>(
            predicate: #Predicate { $0.id == originalID })
        for original in (try? context.fetch(descriptor)) ?? [] {
            original.reimbursedAt = nil
        }
    }
}
