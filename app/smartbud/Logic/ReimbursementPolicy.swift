//
//  ReimbursementPolicy.swift
//  smartbud
//
//  The arithmetic of a partial reimbursement, kept free of SwiftData so it
//  compiles and runs on Linux (`scripts/linux-tests.sh`).
//
//  A claim leaves the account but is expected back. Until the money arrives
//  the user is out of pocket, so the *unreimbursed* part counts as spend; every
//  yuan that comes back removes exactly that much from the spend figure and
//  from the pending balance. `reimbursedAmount` is stored on the claim in the
//  base currency; the account-currency figures are projections through the
//  rate frozen on the original row.
//

import Foundation

enum ReimbursementPolicy {

    /// Why a repayment was refused. Wording lives in the view; the cases are
    /// what the tests pin.
    enum Failure: Error, Equatable {
        /// Income, a repayment row, or an ordinary expense.
        case notAClaim
        /// A written-off claim already has its loss booked; paying it back as
        /// well would count the money twice.
        case alreadyWrittenOff
        case nonPositiveAmount
        /// The repayment would push the total past the claim.
        case exceedsRemaining(remaining: Double)
    }

    /// A stored value fixed to `0...baseAmount` and to cents. Imported and
    /// migrated rows go through here before they can affect any statistic.
    static func clamped(reimbursed: Double, baseAmount: Double) -> Double {
        let base = Money.cents(baseAmount)
        guard base > 0 else { return 0 }
        let value = Money.cents(reimbursed)
        guard value > 0 else { return 0 }
        return Money.double(min(value, base))
    }

    /// Base amount still owed on the claim, floored at zero. Both sides are
    /// rounded to cents first so 3 × 33.33 against 100.00 leaves 0.01 rather
    /// than a floating-point ghost that refuses the last repayment.
    static func remaining(baseAmount: Double, reimbursed: Double) -> Double {
        let left = Money.cents(baseAmount) - Money.cents(clamped(reimbursed: reimbursed,
                                                                baseAmount: baseAmount))
        guard left > 0 else { return 0 }
        return Money.double(left)
    }

    /// Whether the claim has been paid back in full. Kept separate from
    /// `remaining` because zero can also mean a row with no amount at all.
    static func isFullyReimbursed(baseAmount: Double, reimbursed: Double) -> Bool {
        Money.cents(baseAmount) > 0 && remaining(baseAmount: baseAmount,
                                                  reimbursed: reimbursed) == 0
    }

    /// The same balance in the account's currency. There is no second stored
    /// amount to drift: it is the base-currency remainder translated back at
    /// the rate frozen on the claim.
    static func accountRemaining(amount: Double, baseAmount: Double, reimbursed: Double) -> Double {
        let left = remaining(baseAmount: baseAmount, reimbursed: reimbursed)
        guard left > 0 else { return 0 }
        return accountAmount(for: left, originalAmount: amount, originalBaseAmount: baseAmount) ?? 0
    }

    /// Base-currency value of a repayment entered in the claim's currency,
    /// using the rate frozen at entry time (`baseAmount / amount`). Returns
    /// `nil` when there is no usable rate.
    static func baseAmount(for amount: Double,
                           originalAmount: Double,
                           originalBaseAmount: Double) -> Double? {
        guard amount.isFinite, amount > 0,
              originalAmount.isFinite, originalAmount > 0,
              originalBaseAmount.isFinite, originalBaseAmount >= 0 else { return nil }
        let value = originalBaseAmount / originalAmount * amount
        guard value.isFinite else { return nil }
        return Money.double(Money.cents(value))
    }

    /// Account-currency value of a base-currency repayment. The inverse of
    /// `baseAmount(for:originalAmount:originalBaseAmount:)`, capped at the
    /// original so a corrupted rate cannot write more money than was paid.
    static func accountAmount(for base: Double,
                              originalAmount: Double,
                              originalBaseAmount: Double) -> Double? {
        guard base.isFinite, base > 0,
              originalAmount.isFinite, originalAmount > 0,
              originalBaseAmount.isFinite, originalBaseAmount > 0 else { return nil }
        let value = base / originalBaseAmount * originalAmount
        guard value.isFinite else { return nil }
        return Money.double(Money.cents(min(value, originalAmount)))
    }

    /// Whether a new repayment may be written. `amount` and `reimbursed` are
    /// both base-currency amounts; the caller converts the entered figure
    /// with the frozen rate before checking it.
    static func validate(isClaim: Bool,
                         isWrittenOff: Bool,
                         amount: Double,
                         reimbursed: Double,
                         baseAmount: Double) -> Failure? {
        guard isClaim else { return .notAClaim }
        guard !isWrittenOff else { return .alreadyWrittenOff }
        guard amount.isFinite, amount > 0 else { return .nonPositiveAmount }
        let left = remaining(baseAmount: baseAmount, reimbursed: reimbursed)
        guard Money.cents(amount) <= Money.cents(left) else {
            return .exceedsRemaining(remaining: left)
        }
        return nil
    }
}
