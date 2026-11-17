//
//  BadDebtPolicy.swift
//  smartbud
//
//  The rules of writing an unpayable claim off, kept free of SwiftData so they
//  compile and run on Linux (`scripts/linux-tests.sh`) — see
//  `docs/accounting-conventions.md` §2.
//
//  A claim is pass-through money: it left the account, but it never counts as
//  spend because it is expected back. When it is never paid back, the money is
//  gone and the expense becomes real. The original row is *not* touched: a
//  separate expense row carries the loss (`badDebtOf`), so the claim keeps its
//  own history and deleting the write-off restores the pending state.
//
//  The write-off does not move money — no account is involved — so it must not
//  change any account balance. Only the spend side changes.
//

import Foundation

enum BadDebtPolicy {

    /// How long a claim has to be waiting before it may be written off. Below
    /// this the money is usually just late, and a one-tap write-off would
    /// encourage giving up on it.
    static let thresholdDays: Int = 90

    /// Why the money never came back. Stored on the write-off row as its raw
    /// value; the wording lives in the view layer.
    enum Reason: String, CaseIterable, Sendable {
        /// The payer cannot be reached any more.
        case unreachable
        /// The claim was refused.
        case rejected
        /// The company closed or the member of staff left.
        case companyClosed
        case other
    }

    /// Why a write-off was refused. Localised wording lives in the view; the
    /// cases are what the tests pin.
    enum Failure: Error, Equatable {
        /// A write-off row itself, or a row that never was a claim.
        case notAClaim
        /// The money already came back; there is nothing left to lose.
        case alreadySettled
        /// This claim already has a write-off row.
        case alreadyWrittenOff
        /// …the claim may still be paid.
        case tooRecent(daysLeft: Int)
        case nonPositiveAmount
    }

    /// Whole days the claim has been waiting, counted on calendar days so a
    /// claim entered late in the evening does not gain a day overnight.
    static func daysWaiting(claimDate: Date,
                            now: Date,
                            calendar: Calendar = Calendar(identifier: .gregorian)) -> Int {
        let from = calendar.startOfDay(for: claimDate)
        let to = calendar.startOfDay(for: now)
        return calendar.dateComponents([.day], from: from, to: to).day ?? 0
    }

    /// Days still to wait before the write-off becomes available (0 once it
    /// is). Drives the "available in N days" hint.
    static func daysLeft(claimDate: Date, now: Date) -> Int {
        max(0, thresholdDays - daysWaiting(claimDate: claimDate, now: now))
    }

    static func isEligible(claimDate: Date, now: Date) -> Bool {
        daysWaiting(claimDate: claimDate, now: now) >= thresholdDays
    }

    /// Whether a claim may be written off right now.
    ///
    /// `date` is both the check date and the day the loss is booked on, so the
    /// rule "90 days have passed" and the row's own date can never disagree.
    static func validate(isClaim: Bool,
                         isSettled: Bool,
                         isWrittenOff: Bool,
                         claimDate: Date,
                         now: Date,
                         amount: Double) -> Failure? {
        guard isClaim else { return .notAClaim }
        guard !isWrittenOff else { return .alreadyWrittenOff }
        guard !isSettled else { return .alreadySettled }
        guard amount.isFinite, amount > 0 else { return .nonPositiveAmount }
        let waiting = daysWaiting(claimDate: claimDate, now: now)
        guard waiting >= thresholdDays else {
            return .tooRecent(daysLeft: thresholdDays - waiting)
        }
        return nil
    }
}
