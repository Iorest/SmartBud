//
//  InstallmentPolicy.swift
//  smartbud
//
//  Cent-exact installment arithmetic, free of SwiftData so the same schedule
//  is used by the ledger, the UI and the Linux test harness.
//
//  Two rules from docs/accounting-conventions.md §4 are enforced here, not in
//  the views: principal only reduces a liability (it is never a fee), and the
//  whole rounding remainder belongs to the last period. Splitting a payment
//  into `periods` equal shares with a rounded last share keeps the generated
//  rows summing to the plan amount to the cent.
//

import Foundation

enum InstallmentPolicy {

    enum Failure: Error, Equatable {
        case nonPositivePrincipal
        case invalidPeriodCount
        case negativeFee
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

    /// Split `total` into whole-cent shares, with the remainder in the last
    /// share. `Money.cents` returns a currency amount rounded to cents, so
    /// multiply by 100 before dividing — rounding the amount itself to an
    /// integer would silently turn 8.02 into 8.00. Decimal avoids the binary
    /// tail that makes three 33.33 payments add up to 99.989999… in a Double.
    private static func shares(_ total: Double, into count: Int) -> [Decimal] {
        guard count > 0 else { return [] }
        let totalCents = Money.cents(total) * 100
        var quotient = totalCents / Decimal(count)
        var unitCents = Decimal.zero
        NSDecimalRound(&unitCents, &quotient, 0, .down)
        var result = [Decimal](repeating: unitCents / 100, count: count)
        if let last = result.indices.last {
            result[last] = (totalCents - unitCents * Decimal(count - 1)) / 100
        }
        return result
    }

    /// The full plan schedule. Dates are the same calendar day of each
    /// following month; `Calendar` clips an invalid day (31 Jan → 28 Feb) the
    /// same way the rest of the app does.
    static func schedule(principal: Double, fee: Double, periods: Int,
                         firstDate: Date, calendar: Calendar = .current) -> [Period] {
        guard validate(principal: principal, fee: fee, periods: periods) == nil else { return [] }
        let principals = shares(principal, into: periods)
        let fees = shares(fee, into: periods)
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
    /// than the plan originally drew. The final period absorbs the remainder.
    static func repaidPrincipal(principal: Double, periods: Int, executed: Int) -> Double {
        guard periods > 0, principal.isFinite else { return 0 }
        let count = min(max(executed, 0), periods)
        guard count > 0 else { return 0 }
        let totalCents = Money.cents(principal) * 100
        var quotient = totalCents / Decimal(periods)
        var unitCents = Decimal.zero
        NSDecimalRound(&unitCents, &quotient, 0, .down)
        // The final period carries the remainder, so a fully executed plan
        // restores the whole principal — not `unit × periods`, which is a
        // cent short whenever the amount does not divide evenly.
        let repaid = count == periods ? totalCents : unitCents * Decimal(count)
        return Money.double(min(repaid, totalCents) / 100)
    }

    /// Credit restored on the linked account is exactly the repaid principal
    /// — no more. Kept as a named rule so both the ledger and the docs can
    /// point at one function instead of re-deriving the cap.
    static func restoredLimit(principal: Double, periods: Int, executed: Int) -> Double {
        repaidPrincipal(principal: principal, periods: periods, executed: executed)
    }
}
