//
//  InstallmentPolicy.swift
//  smartbud
//
//  Cent-exact installment arithmetic, free of SwiftData so the same schedule
//  is used by the ledger, the UI and the Linux test harness.
//
//  Two rules from docs/accounting-conventions.md §4 are enforced here, not in
//  the views: principal only reduces a liability (it is never a fee), and the
//  whole rounding remainder belongs to one period chosen by the plan. Splitting
//  a payment into `periods` equal shares keeps the generated rows summing to
//  the plan amount to the cent.
//

import Foundation

enum InstallmentPolicy {

    enum Failure: Error, Equatable {
        case nonPositivePrincipal
        case invalidPeriodCount
        case negativeFee
    }

    /// When the total interest/fees enter the generated bills.
    enum InterestTiming: String, Codable {
        /// Split the total across every period (the historical behaviour).
        case perPeriod = "perPeriod"
        /// Put the whole total in the first bill.
        case firstPeriod = "firstPeriod"
    }

    /// How the unpaid principal enters the credit account's outstanding debt.
    /// iCost documents two ways that add the same total but differ in *when*
    /// the debt is recognised. The card balance is this app's debt: a
    /// principal row with `income = true` reduces it (the purchase already
    /// booked the debt), while `income = false` increases it as the bill
    /// arrives. `installmentKind = 2` keeps either direction out of spend
    /// and income totals.
    enum LiabilityTiming: String, Codable {
        /// Debt recognised at creation; each generated bill restores credit.
        case atCreation = "atCreation"
        /// Debt recognised as each bill is generated; no credit restored.
        case perPeriod = "perPeriod"
    }

    /// Which bill absorbs the whole cent rounding remainder.
    enum RemainderPlacement: String, Codable {
        case last = "last"
        case first = "first"
    }

    /// Choices persisted on an installment plan. A nil stored value (a plan
    /// written before TELE-84) resolves to `default`, so old data and old
    /// backups keep the historical schedule.
    struct Options: Codable, Equatable {
        var interestTiming: InterestTiming = .perPeriod
        var liabilityTiming: LiabilityTiming = .atCreation
        var remainderPlacement: RemainderPlacement = .last

        static let `default` = Options()
    }

    /// One monthly bill. `index` is 1-based; `kind` is applied by the ledger.
    struct Period: Equatable {
        var index: Int
        var date: Date
        var principal: Double
        var fee: Double
    }

    /// Called before a plan is written. A plan with no principal or an
    /// unreasonable term cannot produce a meaningful schedule.
    static func validate(principal: Double, fee: Double, periods: Int) -> Failure? {
        guard principal.isFinite, Money.cents(principal) > 0 else { return .nonPositivePrincipal }
        guard periods >= 1, periods <= 360 else { return .invalidPeriodCount }
        guard fee.isFinite, Money.cents(fee) >= 0 else { return .negativeFee }
        return nil
    }

    /// Split `total` into whole-cent shares, putting the rounding remainder
    /// in the first or the last share. `Money.cents` returns a currency
    /// amount rounded to cents, so multiply by 100 before dividing — rounding
    /// the amount itself to an integer would silently turn 8.02 into 8.00.
    /// Decimal avoids the binary tail that makes three 33.33 payments add up
    /// to 99.989999… in a Double.
    private static func shares(_ total: Double, into count: Int,
                               remainderAt: RemainderPlacement = .last) -> [Decimal] {
        guard count > 0 else { return [] }
        let totalCents = Money.cents(total) * 100
        var quotient = totalCents / Decimal(count)
        var unitCents = Decimal.zero
        NSDecimalRound(&unitCents, &quotient, 0, .down)
        var result = [Decimal](repeating: unitCents / 100, count: count)
        let remainder = totalCents - unitCents * Decimal(count)
        switch remainderAt {
        case .last:
            if let last = result.indices.last { result[last] += remainder / 100 }
        case .first:
            if let first = result.indices.first { result[first] += remainder / 100 }
        }
        return result
    }

    /// The full plan schedule. Dates are the same calendar day of each
    /// following month; `Calendar` clips an invalid day (31 Jan → 28 Feb) the
    /// same way the rest of the app does. Omitting `options` gives the
    /// historical per-period / at-creation / last-period schedule.
    static func schedule(principal: Double, fee: Double, periods: Int,
                         firstDate: Date, calendar: Calendar = .current,
                         options: Options = .default) -> [Period] {
        guard validate(principal: principal, fee: fee, periods: periods) == nil else { return [] }
        let principals = shares(principal, into: periods,
                                remainderAt: options.remainderPlacement)
        var fees: [Decimal]
        switch options.interestTiming {
        case .perPeriod:
            fees = shares(fee, into: periods, remainderAt: options.remainderPlacement)
        case .firstPeriod:
            // The whole total lands in one bill; there is no share to round.
            fees = [Decimal](repeating: .zero, count: periods)
            if let first = fees.indices.first { fees[first] = Money.cents(fee) }
        }
        return (0..<periods).map { offset in
            Period(
                index: offset + 1,
                date: calendar.date(byAdding: .month, value: offset, to: firstDate) ?? firstDate,
                principal: Money.double(principals[offset]),
                fee: Money.double(fees[offset])
            )
        }
    }

    /// Principal repaid after `executed` periods. The counter is clamped to
    /// the term, so a corrupt or imported value can never restore more credit
    /// than the plan originally drew. The chosen remainder period absorbs the
    /// tail, so a fully executed plan restores the whole principal.
    static func repaidPrincipal(principal: Double, periods: Int, executed: Int,
                                remainderAt: RemainderPlacement = .last) -> Double {
        guard periods > 0, principal.isFinite else { return 0 }
        let count = min(max(executed, 0), periods)
        guard count > 0 else { return 0 }
        let totalCents = Money.cents(principal) * 100
        var quotient = totalCents / Decimal(periods)
        var unitCents = Decimal.zero
        NSDecimalRound(&unitCents, &quotient, 0, .down)
        let remainder = totalCents - unitCents * Decimal(periods)
        let repaid: Decimal
        switch remainderAt {
        case .last:
            repaid = count == periods ? totalCents : unitCents * Decimal(count)
        case .first:
            repaid = unitCents * Decimal(count) + (count >= 1 ? remainder : 0)
        }
        return Money.double(min(repaid, totalCents) / 100)
    }

    /// Credit restored on the linked account is exactly the repaid principal
    /// — no more. Kept as a named rule so both the ledger and the docs can
    /// point at one function instead of re-deriving the cap.
    static func restoredLimit(principal: Double, periods: Int, executed: Int,
                              remainderAt: RemainderPlacement = .last) -> Double {
        repaidPrincipal(principal: principal, periods: periods,
                        executed: executed, remainderAt: remainderAt)
    }
}

extension InstallmentPolicy.Options {
    /// Missing and partially written keys fall back one by one, so a backup
    /// that predates any of the options still decodes to `default`.
    private enum CodingKeys: String, CodingKey {
        case interestTiming, liabilityTiming, remainderPlacement
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        interestTiming = try container.decodeIfPresent(InstallmentPolicy.InterestTiming.self,
            forKey: .interestTiming) ?? .perPeriod
        liabilityTiming = try container.decodeIfPresent(InstallmentPolicy.LiabilityTiming.self,
            forKey: .liabilityTiming) ?? .atCreation
        remainderPlacement = try container.decodeIfPresent(InstallmentPolicy.RemainderPlacement.self,
            forKey: .remainderPlacement) ?? .last
    }
}
