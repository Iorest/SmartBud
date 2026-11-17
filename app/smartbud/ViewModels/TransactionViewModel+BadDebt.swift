//
//  TransactionViewModel+BadDebt.swift
//  smartbud
//
//  UI-facing write-off actions. The rows and the rules live in `BadDebtLedger`
//  / `BadDebtPolicy`; this file only maps menus and sheets onto them and keeps
//  the save (and its failure) in one place.
//

import Foundation

extension TransactionViewModel {

    enum BadDebtResult: Equatable {
        case success
        /// The policy said no; the sheet shows the reason and stays open.
        case refused(BadDebtPolicy.Failure)
        /// The store refused the write. Never report success for this.
        case saveFailed
    }

    /// The claim a loss row was written for.
    func writeOffClaim(for writeOffRow: TransactionModel) -> TransactionModel? {
        BadDebtLedger.claim(for: writeOffRow, in: repo.context)
    }

    /// The loss row written for a written-off claim, if there is one.
    func writeOffRow(for claim: TransactionModel) -> TransactionModel? {
        BadDebtLedger.writeOffs(of: claim, in: repo.context).first
    }

    /// Claims can be written off only once the waiting period is over. The
    /// pending sheet shows the countdown instead of the action until then.
    func canWriteOff(_ claim: TransactionModel) -> Bool {
        claim.isPendingReimbursement && BadDebtPolicy.isEligible(
            claimDate: claim.wrappedDate, now: .now)
    }

    /// Days left before the action appears (0 when it already does).
    func daysUntilWriteOff(_ claim: TransactionModel) -> Int {
        BadDebtPolicy.daysLeft(claimDate: claim.wrappedDate, now: .now)
    }

    /// Writes the loss for a claim, commits it, and reports what happened.
    func writeOff(_ claim: TransactionModel,
                  reason: BadDebtPolicy.Reason,
                  date: Date = .now) -> BadDebtResult {
        switch BadDebtLedger.writeOff(claim, reason: reason, date: date, in: repo.context) {
        case .failure(let failure):
            return .refused(failure)
        case .success:
            return repo.save() ? .success : .saveFailed
        }
    }

    /// Removes the loss row; the claim goes back into the pending list.
    func undoWriteOff(_ writeOffRow: TransactionModel) {
        guard writeOffRow.isBadDebt else { return }
        BadDebtLedger.undo(writeOffRow, in: repo.context)
        repo.save()
    }
}
