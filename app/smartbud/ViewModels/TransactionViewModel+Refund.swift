//
//  TransactionViewModel+Refund.swift
//  smartbud
//
//  UI-facing refund actions. The rows and the rules live in `RefundLedger` /
//  `RefundPolicy`; this file only maps sheets onto them and keeps the save
//  (and its failure) in one place.
//

import Foundation
import SwiftData

extension TransactionViewModel {

    enum RefundResult: Equatable {
        case success
        /// The policy said no; the sheet shows the reason and stays open.
        case refused(RefundPolicy.Failure)
        /// The store refused the write. Never report success for this.
        case saveFailed
    }

    /// How much of the expense is still refundable, zero when it is not one.
    func remainingRefundable(for original: TransactionModel) -> Double {
        guard original.canBeRefunded else { return 0 }
        return RefundLedger.remaining(for: original, in: repo.context)
    }

    func canRefund(_ original: TransactionModel) -> Bool {
        original.canBeRefunded && remainingRefundable(for: original) > 0
    }

    func refunds(of original: TransactionModel) -> [TransactionModel] {
        RefundLedger.refunds(of: original, in: repo.context)
    }

    func refundOriginal(for refund: TransactionModel) -> TransactionModel? {
        RefundLedger.original(for: refund, in: repo.context)
    }

    /// Records a refund, commits it, and reports what happened.
    func addRefund(to original: TransactionModel,
                   amount: Double,
                   date: Date,
                   account: AccountModel?,
                   note: String = "") -> RefundResult {
        switch RefundLedger.refund(original, amount: amount, date: date,
                                   account: account, note: note, in: repo.context) {
        case .failure(let failure):
            return .refused(failure)
        case .success:
            return repo.save() ? .success : .saveFailed
        }
    }

    /// Edits an existing refund row. Same refusals as creating one, checked
    /// against what the other refunds leave free.
    func updateRefund(_ refund: TransactionModel,
                      amount: Double,
                      date: Date,
                      account: AccountModel?,
                      note: String = "") -> RefundResult {
        if let failure = RefundLedger.update(refund, amount: amount, date: date,
                                             account: account, note: note,
                                             in: repo.context) {
            return .refused(failure)
        }
        return repo.save() ? .success : .saveFailed
    }
}
