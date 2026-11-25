//
//  BadDebtLedger.swift
//  smartbud
//
//  The write-off half of a claim. A claim waits in the pending list until the
//  money comes back; if it never does, the loss becomes real spend. That loss
//  is its own expense row pointing at the claim (`badDebtOf`) — the claim row
//  is never edited or deleted, so its history stays readable and removing the
//  write-off simply puts it back into the pending list.
//
//  Rules live in `BadDebtPolicy` (Foundation only, tested on Linux); this file
//  only fetches, mutates and cascades.
//

import Foundation
import SwiftData

@MainActor
enum BadDebtLedger {

    /// Every write-off row in the store. `#Predicate` cannot compare an
    /// optional UUID inside the app's SwiftData build reliably, so the rows are
    /// filtered in memory — the write-off set is small next to the ledger.
    static func allWriteOffs(in context: ModelContext) -> [TransactionModel] {
        let descriptor = FetchDescriptor<TransactionModel>(
            predicate: #Predicate { $0.badDebtOf != nil })
        return (try? context.fetch(descriptor)) ?? []
    }

    static func writeOffs(of claim: TransactionModel, in context: ModelContext) -> [TransactionModel] {
        allWriteOffs(in: context).filter { $0.badDebtOf == claim.id }
    }

    static func claim(for writeOff: TransactionModel, in context: ModelContext) -> TransactionModel? {
        guard let claimID = writeOff.badDebtOf else { return nil }
        let descriptor = FetchDescriptor<TransactionModel>(
            predicate: #Predicate { $0.id == claimID })
        return (try? context.fetch(descriptor))?.first
    }

    /// Reason stored on a write-off row. An unknown or missing raw value reads
    /// as `.other` instead of being dropped: the row still means "never paid".
    static func reason(of writeOff: TransactionModel) -> BadDebtPolicy.Reason {
        writeOff.badDebtReason.flatMap(BadDebtPolicy.Reason.init(rawValue:)) ?? .other
    }

    // MARK: - Writing

    /// Writes the loss row for a claim (not saved; the caller commits). The
    /// amount is the claim's **outstanding** base amount — money already paid
    /// back must not be written off a second time. The write-off has no
    /// account, so it is recorded in the base currency and matches what the
    /// claim would have added to spend had it not been a claim.
    static func writeOff(_ claim: TransactionModel,
                         reason: BadDebtPolicy.Reason,
                         date: Date,
                         in context: ModelContext) -> Result<TransactionModel, BadDebtPolicy.Failure> {
        let outstanding = ReimbursementPolicy.remaining(baseAmount: claim.wrappedBaseAmount,
                                                        reimbursed: claim.reimbursedAmount)
        if let failure = BadDebtPolicy.validate(
            isClaim: claim.reimbursable && !claim.income && claim.badDebtOf == nil,
            isSettled: claim.reimbursedAt != nil,
            isWrittenOff: claim.badDebtAt != nil,
            claimDate: claim.wrappedDate,
            now: date,
            amount: outstanding
        ) {
            return .failure(failure)
        }

        claim.badDebtAt = date
        let name = claim.wrappedNote.isEmpty ? claim.wrappedCategoryName : claim.wrappedNote
        // The loss belongs to the claim's ledger, not to whichever book the
        // user happens to be viewing when the write-off is recorded.
        let row = TransactionModel(
            note: String.appFormatted("Bad debt · %@", name),
            category: claim.category,
            // No account: nothing left an account the day the money was given
            // up on. Keeping it empty is what keeps the balance unchanged.
            account: nil,
            baseAmount: outstanding,
            income: false,
            amount: outstanding,
            date: date,
            badDebtOf: claim.id,
            badDebtReason: reason.rawValue,
            merchant: claim.merchant,
            merchantKey: claim.merchantKey,
            bookID: claim.bookID
        )
        context.insert(row)
        return .success(row)
    }

    /// Keeps the loss row in step when the claim's amount changes. The date
    /// stays where the loss was booked: moving it would rewrite the period the
    /// money was given up on. Only the still-unpaid part can be lost.
    static func sync(_ claim: TransactionModel, in context: ModelContext) {
        guard claim.badDebtAt != nil else { return }
        let outstanding = ReimbursementPolicy.remaining(baseAmount: claim.wrappedBaseAmount,
                                                        reimbursed: claim.reimbursedAmount)
        for row in writeOffs(of: claim, in: context) {
            row.amount = outstanding
            row.baseAmount = outstanding
            row.category = claim.category
        }
    }

    /// Drops the write-off because the row is no longer a claim at all (the
    /// user cleared the flag or moved it to an income category). The loss row
    /// would otherwise keep counting spend for money that is no longer being
    /// claimed back.
    static func clearWriteOff(of claim: TransactionModel, in context: ModelContext) {
        claim.badDebtAt = nil
        for row in writeOffs(of: claim, in: context) {
            context.delete(row)
        }
    }

    /// Undoes a write-off: the claim goes back into the pending list and the
    /// loss row is removed (not saved; the caller commits).
    static func undo(_ writeOffRow: TransactionModel, in context: ModelContext) {
        guard writeOffRow.badDebtOf != nil else { return }
        claim(for: writeOffRow, in: context)?.badDebtAt = nil
        context.delete(writeOffRow)
    }

    /// Called before deleting a row. The pair lives and dies together: a claim
    /// takes its loss row with it (a loss pointing at a deleted claim is an
    /// orphan), and deleting the loss row puts the claim back into the pending
    /// list.
    static func prepareForDeletion(of txn: TransactionModel, in context: ModelContext) {
        if txn.badDebtOf != nil {
            claim(for: txn, in: context)?.badDebtAt = nil
            return
        }
        for row in writeOffs(of: txn, in: context) {
            context.delete(row)
        }
    }
}
