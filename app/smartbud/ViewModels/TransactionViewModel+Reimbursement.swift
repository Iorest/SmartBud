//
//  TransactionViewModel+Reimbursement.swift
//  smartbud
//
//  The claim flag and its settlement. The two rows themselves are maintained by
//  `ReimbursementLedger`; this file only maps the UI actions onto it.
//

import Foundation

extension TransactionViewModel {

    // MARK: Reimbursement

    enum ReimbursementResult: Equatable {
        case success
        /// The policy said no; the sheet shows the reason and stays open.
        case refused(ReimbursementPolicy.Failure)
        /// The store refused the write. Never report success for this.
        case saveFailed
    }

    /// Turns the claim flag on/off. Only expenses can be claimed back, and
    /// clearing the flag also clears the paid-back total and date.
    func setReimbursable(_ reimbursable: Bool, for txn: TransactionModel) {
        let allowed = reimbursable && !txn.income && !txn.adjustment && !txn.isRefund
        guard txn.reimbursable != allowed else { return }
        txn.reimbursable = allowed
        if !allowed {
            ReimbursementLedger.unsettle(txn, in: repo.context)
            BadDebtLedger.clearWriteOff(of: txn, in: repo.context)
        }
        repo.save()
    }

    /// Full settlement for the one-tap swipe. Partial repayments go through
    /// `recordReimbursement`; undoing either removes every repayment row.
    func setReimbursed(_ reimbursed: Bool, for txn: TransactionModel) {
        guard txn.reimbursable, !txn.income else { return }
        // A written-off claim already carries its loss: paying it back as well
        // would count the money twice. Undo the write-off first.
        guard txn.badDebtAt == nil else { return }

        if reimbursed {
            guard txn.reimbursedAt == nil else { return }
            ReimbursementLedger.settle(txn, in: repo.context)
        } else {
            guard txn.reimbursedAt != nil || txn.reimbursedAmount > 0 else { return }
            ReimbursementLedger.unsettle(txn, in: repo.context)
        }
        repo.save()
    }

    /// Records one instalment and commits it. `amount` is entered in the
    /// claim's account currency; the ledger converts it with the frozen rate.
    func recordReimbursement(_ claim: TransactionModel,
                             amount: Double,
                             date: Date = .now) -> ReimbursementResult {
        switch ReimbursementLedger.repay(claim, amount: amount, date: date,
                                         in: repo.context) {
        case .failure(let failure):
            return .refused(failure)
        case .success:
            return repo.save() ? .success : .saveFailed
        }
    }

    /// Every repayment row of `txn`, oldest first.
    func repayments(of txn: TransactionModel) -> [TransactionModel] {
        ReimbursementLedger.repayments(for: txn, in: repo.context)
    }

    /// The most recent income row that pays `txn` back, if it exists.
    func repayment(for txn: TransactionModel) -> TransactionModel? {
        ReimbursementLedger.repayment(for: txn, in: repo.context)
    }
}
