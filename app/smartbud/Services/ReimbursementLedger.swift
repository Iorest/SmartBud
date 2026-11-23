//
//  ReimbursementLedger.swift
//  smartbud
//
//  The two halves of a reimbursement. A claim leaves the account; each time
//  money comes back an income row is written against it and the claim's
//  `reimbursedAmount` grows by that much. The outstanding part is the money
//  the user is still out of pocket for and is what counts as spend.
//
//  Keeping pairing, amount accounting and cleanup here means every caller —
//  swipe, sheet, edit, delete, import — follows the same rules.
//

import Foundation
import SwiftData

@MainActor
enum ReimbursementLedger {

    /// Income rows that settle claims.
    static func repayments(in context: ModelContext) -> [TransactionModel] {
        let descriptor = FetchDescriptor<TransactionModel>(
            predicate: #Predicate { $0.reimbursementOf != nil })
        return (try? context.fetch(descriptor)) ?? []
    }

    /// Every repayment of one claim, oldest first. A claim may be paid back
    /// several times; each instalment keeps its own row, date and amount.
    static func repayments(for claim: TransactionModel,
                           in context: ModelContext) -> [TransactionModel] {
        repayments(in: context)
            .filter { $0.reimbursementOf == claim.id }
            .sorted { $0.wrappedDate < $1.wrappedDate }
    }

    /// Kept for callers that only need one row (a fully settled claim has
    /// exactly one). New code that adds amounts should use `repayments(for:)`.
    static func repayment(for claim: TransactionModel, in context: ModelContext) -> TransactionModel? {
        repayments(for: claim, in: context).last
    }

    // MARK: - Migration

    /// Backfills rows written before `reimbursedAmount` existed: a full
    /// settlement had only `reimbursedAt`. Also repairs out-of-range values
    /// from hand-edited imports. Reentrant — a second run is a no-op.
    @discardableResult
    static func migrate(in context: ModelContext) -> Int {
        let descriptor = FetchDescriptor<TransactionModel>()
        let rows = (try? context.fetch(descriptor)) ?? []
        var filled = 0
        for txn in rows {
            let isClaim = txn.reimbursable && !txn.income && txn.reimbursementOf == nil
            let target = isClaim
                ? ReimbursementPolicy.clamped(reimbursed: txn.reimbursedAt == nil
                                              ? txn.reimbursedAmount
                                              : txn.wrappedBaseAmount,
                                              baseAmount: txn.wrappedBaseAmount)
                : 0
            guard Money.cents(txn.reimbursedAmount) != Money.cents(target) else { continue }
            txn.reimbursedAmount = target
            filled += 1
        }
        if filled > 0 { try? context.save() }
        return filled
    }

    // MARK: - Writing

    /// Records one repayment, in the claim's account currency. The base
    /// currency is derived with the rate frozen on the claim; the income row
    /// gets the same account and the original's note for a readable ledger.
    @discardableResult
    static func repay(_ claim: TransactionModel,
                      amount: Double,
                      date: Date = .now,
                      in context: ModelContext) -> Result<TransactionModel, ReimbursementPolicy.Failure> {
        guard claim.reimbursable, !claim.income, claim.reimbursementOf == nil else {
            return .failure(.notAClaim)
        }
        if let failure = ReimbursementPolicy.validate(
            isClaim: true,
            isWrittenOff: claim.badDebtAt != nil,
            amount: ReimbursementPolicy.baseAmount(for: amount,
                                                   originalAmount: claim.amount,
                                                   originalBaseAmount: claim.wrappedBaseAmount) ?? 0,
            reimbursed: claim.reimbursedAmount,
            baseAmount: claim.wrappedBaseAmount
        ) {
            // A non-convertible amount reaches the policy as zero, which is
            // reported as "enter an amount greater than zero".
            return .failure(failure)
        }
        guard let base = ReimbursementPolicy.baseAmount(for: amount,
                                                        originalAmount: claim.amount,
                                                        originalBaseAmount: claim.wrappedBaseAmount),
              let rowAmount = ReimbursementPolicy.accountAmount(for: base,
                                                               originalAmount: claim.amount,
                                                               originalBaseAmount: claim.wrappedBaseAmount)
        else { return .failure(.nonPositiveAmount) }

        let total = Money.double(Money.cents(claim.reimbursedAmount) + Money.cents(base))
        let full = ReimbursementPolicy.isFullyReimbursed(baseAmount: claim.wrappedBaseAmount,
                                                         reimbursed: total)
        let name = claim.wrappedNote.isEmpty ? claim.wrappedCategoryName : claim.wrappedNote
        let row = TransactionModel(
            note: String.appFormatted("Reimbursement · %@", name),
            category: nil,
            account: claim.account,
            baseAmount: base,
            income: true,
            amount: rowAmount,
            date: date,
            reimbursementOf: claim.id
        )
        claim.reimbursedAmount = total
        if full { claim.reimbursedAt = date }
        context.insert(row)
        return .success(row)
    }

    /// Full settlement, kept for the one-tap swipe and existing callers.
    /// Omitting `amount` means "whatever is still owed"; calling it again on
    /// a fully settled claim returns the existing row instead of paying twice.
    @discardableResult
    static func settle(_ claim: TransactionModel,
                       in context: ModelContext,
                       date: Date = .now,
                       amount: Double? = nil) -> TransactionModel? {
        let entered = amount ?? ReimbursementPolicy.accountRemaining(
            amount: claim.amount,
            baseAmount: claim.wrappedBaseAmount,
            reimbursed: claim.reimbursedAmount)
        switch repay(claim, amount: entered, date: date, in: context) {
        case .success(let row):
            return row
        case .failure:
            if amount == nil, claim.reimbursedAt != nil {
                return repayment(for: claim, in: context)
            }
            return nil
        }
    }

    /// Undoes every repayment of the claim, not just the last one.
    static func unsettle(_ claim: TransactionModel, in context: ModelContext) {
        claim.reimbursedAmount = 0
        claim.reimbursedAt = nil
        deleteRepayments(for: claim, in: context)
    }

    /// Keeps the repayment rows in step when the claim's amount or account
    /// changes. A full settlement follows the new amount exactly; a partial
    /// one scales its instalments so their base-currency sum still equals the
    /// stored `reimbursedAmount`, with any rounding remainder on the last row.
    static func sync(_ claim: TransactionModel, in context: ModelContext) {
        let rows = repayments(for: claim, in: context)
        guard !rows.isEmpty else { return }
        let base = claim.wrappedBaseAmount

        // A full settlement must also split across its instalments: writing
        // the whole new amount on every row would credit the account several
        // times and leave the rows out of step with `reimbursedAmount`.
        let targetBase = claim.reimbursedAt != nil
            ? ReimbursementPolicy.clamped(reimbursed: base, baseAmount: base)
            : ReimbursementPolicy.clamped(reimbursed: claim.reimbursedAmount,
                                          baseAmount: base)
        claim.reimbursedAmount = targetBase
        let target = Money.cents(targetBase)
        let oldTotal = Money.sum(rows.map(\.wrappedBaseAmount))
        guard oldTotal > 0, rows.first != nil else {
            rows.first?.baseAmount = capped
            rows.first?.amount = ReimbursementPolicy.accountAmount(for: capped,
                                                                  originalAmount: claim.amount,
                                                                  originalBaseAmount: base) ?? claim.amount
            rows.first?.account = claim.account
            return
        }

        var left = target
        for (index, row) in rows.enumerated() {
            let share: Decimal
            if index == rows.count - 1 {
                share = left
            } else {
                let proportional = min(Money.cents(row.wrappedBaseAmount) / oldTotal * target, left)
                share = proportional
                left -= proportional
            }
            row.baseAmount = Money.double(Money.rounded(share))
            row.amount = ReimbursementPolicy.accountAmount(for: row.baseAmount,
                                                          originalAmount: claim.amount,
                                                          originalBaseAmount: base) ?? row.amount
            row.account = claim.account
        }
    }

    /// The mirror image: editing a repayment row moves the claim's amount
    /// with it, so the pair can never drift apart (an 88 expense paid back by
    /// a 120 income row would quietly create 32 of profit). The account is
    /// deliberately *not* copied: the money may land on another card.
    static func syncClaim(from repayment: TransactionModel, in context: ModelContext) {
        guard let originalID = repayment.reimbursementOf else { return }
        let descriptor = FetchDescriptor<TransactionModel>(
            predicate: #Predicate { $0.id == originalID })
        guard let claim = (try? context.fetch(descriptor))?.first else { return }
        claim.amount = repayment.amount
        claim.baseAmount = repayment.wrappedBaseAmount

        let rows = repayments(for: claim, in: context)
        let total = Money.double(Money.sum(rows.map(\.wrappedBaseAmount)))
        claim.reimbursedAmount = ReimbursementPolicy.clamped(reimbursed: total,
                                                             baseAmount: claim.wrappedBaseAmount)
        if ReimbursementPolicy.isFullyReimbursed(baseAmount: claim.wrappedBaseAmount,
                                                 reimbursed: claim.reimbursedAmount) {
            claim.reimbursedAt = rows.map(\.wrappedDate).max() ?? repayment.wrappedDate
        } else {
            claim.reimbursedAt = nil
        }
    }

    /// Deletes all income rows belonging to `claim`.
    static func deleteRepayments(for claim: TransactionModel, in context: ModelContext) {
        for row in repayments(for: claim, in: context) {
            context.delete(row)
        }
    }

    /// Called before deleting a row. A claim takes its repayments with it;
    /// deleting one repayment reduces the claim's paid-back total, so its
    /// outstanding balance and pending badge recover without a stored counter
    /// getting out of step.
    static func prepareForDeletion(of txn: TransactionModel, in context: ModelContext) {
        if txn.reimbursable {
            deleteRepayments(for: txn, in: context)
        }
        guard let originalID = txn.reimbursementOf else { return }
        let descriptor = FetchDescriptor<TransactionModel>(
            predicate: #Predicate { $0.id == originalID })
        for original in (try? context.fetch(descriptor)) ?? [] {
            let rows = repayments(for: original, in: context).filter { $0.id != txn.id }
            let total = Money.double(Money.sum(rows.map(\.wrappedBaseAmount)))
            original.reimbursedAmount = ReimbursementPolicy.clamped(
                reimbursed: total, baseAmount: original.wrappedBaseAmount)
            if !ReimbursementPolicy.isFullyReimbursed(baseAmount: original.wrappedBaseAmount,
                                                      reimbursed: original.reimbursedAmount) {
                original.reimbursedAt = nil
            }
        }
    }
}
