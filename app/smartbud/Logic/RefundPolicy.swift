//
//  RefundPolicy.swift
//  smartbud
//
//  The arithmetic and the rules of a refund, kept free of SwiftData so they
//  compile and run on Linux (`scripts/linux-tests.sh`) — see
//  `docs/accounting-conventions.md` §3.
//
//  A refund is the counterpart of a purchase: money comes back, but nothing
//  was earned. It reduces the original expense's category spend in the period
//  the money arrived, may be recorded several times as long as the total
//  never exceeds the original amount, and must use the exchange rate frozen on
//  the original row — re-translating a refund at today's rate would rewrite
//  history.
//

import Foundation

enum RefundPolicy {

    /// Why a refund was refused. Localised wording lives in the view; the
    /// cases are what the tests pin.
    enum Failure: Error, Equatable {
        /// Income, a balance adjustment, a claim, or a refund itself.
        case notAnExpense
        case nonPositiveAmount
        /// The refund would push the total past the original amount.
        case exceedsRemaining(remaining: Double)
        /// Money cannot arrive before it left.
        case arrivedBeforeExpense
        /// The refund must land in the same currency the purchase used, or
        /// the frozen rate no longer applies.
        case currencyMismatch
    }

    /// Original amount minus everything already refunded, floored at zero.
    /// Both sides are rounded to cents first, so 3 × 33.33 against 100.00
    /// leaves 0.01 rather than a 1e-14 ghost that refuses the last refund.
    static func remaining(originalAmount: Double, refunded: Double) -> Double {
        let left = Money.cents(originalAmount) - Money.cents(refunded)
        guard left > 0 else { return 0 }
        return Money.double(left)
    }

    /// Base-currency value of a refund, converted with the rate that was
    /// frozen on the original row (`baseAmount / amount`). Returns `nil` when
    /// the original carries no usable amount — there is no rate to apply.
    static func baseAmount(originalBaseAmount: Double,
                           originalAmount: Double,
                           refundAmount: Double) -> Double? {
        guard originalAmount.isFinite, originalAmount > 0,
              originalBaseAmount.isFinite, originalBaseAmount >= 0,
              refundAmount.isFinite, refundAmount > 0 else { return nil }
        let value = originalBaseAmount / originalAmount * refundAmount
        guard value.isFinite else { return nil }
        return Money.double(Money.cents(value))
    }

    /// Whether a new (or edited) refund may be written.
    ///
    /// `refunded` is the total already recorded against the original. When
    /// editing, the caller passes the total *excluding* the row being changed,
    /// so the edited amount is checked against what is still free.
    static func validate(amount: Double,
                         date: Date,
                         originalAmount: Double,
                         originalDate: Date,
                         refunded: Double) -> Failure? {
        guard amount.isFinite, amount > 0 else { return .nonPositiveAmount }
        let left = remaining(originalAmount: originalAmount, refunded: refunded)
        guard Money.cents(amount) <= Money.cents(left) else {
            return .exceedsRemaining(remaining: left)
        }
        guard date >= originalDate else { return .arrivedBeforeExpense }
        return nil
    }

    /// Whether an edit keeps the refund inside the original amount. `self`
    /// (the row being edited) is not part of `refunded`.
    static func validateEdit(amount: Double,
                             date: Date,
                             originalAmount: Double,
                             originalDate: Date,
                             refundedExcludingSelf: Double) -> Failure? {
        validate(amount: amount, date: date,
                 originalAmount: originalAmount, originalDate: originalDate,
                 refunded: refundedExcludingSelf)
    }
}
