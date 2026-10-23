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

    /// Turns the claim flag on/off. Only expenses can be claimed back, and
    /// clearing the flag also clears the "paid back" date.
    func setReimbursable(_ reimbursable: Bool, for txn: TransactionModel) {
        let allowed = reimbursable && !txn.income && !txn.adjustment
        guard txn.reimbursable != allowed else { return }
        txn.reimbursable = allowed
        if !allowed {
            ReimbursementLedger.unsettle(txn, in: repo.context)
        }
        repo.save()
    }

    /// Records (or clears) the moment the money came back. Settling also
    /// writes the matching income row (see `ReimbursementLedger`); undoing it
    /// removes that row again.
    func setReimbursed(_ reimbursed: Bool, for txn: TransactionModel) {
        guard txn.reimbursable, !txn.income else { return }

        if reimbursed {
            guard txn.reimbursedAt == nil else { return }
            ReimbursementLedger.settle(txn, in: repo.context)
        } else {
            guard txn.reimbursedAt != nil else { return }
            ReimbursementLedger.unsettle(txn, in: repo.context)
        }
        repo.save()
    }

    /// The income row that pays `txn` back, if it exists.
    func repayment(for txn: TransactionModel) -> TransactionModel? {
        ReimbursementLedger.repayment(for: txn, in: repo.context)
    }
}
