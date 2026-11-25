//
//  AccountBalance.swift
//  smartbud
//
//  Pure balance maths, kept out of SwiftData so it can be unit tested
//  without a model container.
//

import Foundation

/// Pure balance maths, kept separate from SwiftData so it is testable without
/// a model container.
enum AccountBalance {
    static func current(
        opening: Double,
        transactions: [(amount: Double, income: Bool, isRefund: Bool)],
        transfersIn: Double = 0,
        transfersOut: Double = 0
    ) -> Double {
        // A refund is money coming back even though it is not income, so it
        // has to move the balance the other way from an expense.
        let spent = transactions.reduce(opening) { total, txn in
            total + (txn.income || txn.isRefund ? txn.amount : -txn.amount)
        }
        return spent + transfersIn - transfersOut
    }

    /// Signed row needed to move `current` to `target`, or nil when they
    /// already match to the cent. Kept here so the adjustment invariant can
    /// be tested without SwiftData or the rate store.
    static func adjustmentDelta(target: Double, current: Double) -> Double? {
        guard target.isFinite, current.isFinite else { return nil }
        let delta = Money.double(Money.cents(target) - Money.cents(current))
        return delta == 0 ? nil : delta
    }
}

// MARK: - Credit cards

/// The card terms stored on an account. All three are optional: a card without
/// a limit has no credit warning, and statement days only drive the cycle card.
struct CreditTerms: Equatable {
    var limit: Double?
    var statementDay: Int?
    var dueDay: Int?
}

struct CreditUsage: Equatable {
    /// Outstanding debt only: a positive (overpaid) card balance uses 0.
    let used: Double
    /// `limit - debt + overpayment`, i.e. `limit + balance`. Negative means
    /// the card is over its limit; the write is still allowed, the UI warns.
    let available: Double
    /// Debt incurred in the current statement cycle, capped by the balance.
    let dueThisCycle: Double
    let isOverLimit: Bool
}

enum CreditCard {
    static func isCredit(kind: Int) -> Bool { kind == 2 }  // AccountKind.credit.rawValue

    static func sanitized(limit: Double?, statementDay: Int?, dueDay: Int?,
                          kind: Int) -> CreditTerms {
        guard isCredit(kind: kind) else {
            return CreditTerms(limit: nil, statementDay: nil, dueDay: nil)
        }
        return CreditTerms(
            limit: validLimit(limit),
            statementDay: validDay(statementDay),
            dueDay: validDay(dueDay)
        )
    }

    static func usage(limit: Double?, balance: Double, cycleSpend: Double) -> CreditUsage? {
        guard let limit = validLimit(limit), balance.isFinite else { return nil }
        let spend = cycleSpend.isFinite ? max(0, cycleSpend) : 0
        let debt = max(0, -balance)
        let used = debt
        // Overpayment raises available credit; it is not "used" credit.
        let available = Money.double(Money.cents(limit + balance))
        return CreditUsage(
            used: used,
            available: available,
            dueThisCycle: min(debt, spend),
            isOverLimit: Money.cents(used) > Money.cents(limit)
        )
    }

    /// Half-open `[start, end)` window for the statement that contains `now`.
    /// A day past the end of a short month is clamped to that month's last day.
    static func cycle(statementDay: Int?, at now: Date,
                      calendar: Calendar = .current) -> (start: Date, end: Date)? {
        guard let day = validDay(statementDay) else { return nil }
        let cal = calendar
        let parts = cal.dateComponents([.year, .month], from: now)
        guard let year = parts.year, let month = parts.month,
              let first = cycleStart(day: day, year: year, month: month, calendar: cal),
              let next = cycleStart(day: day, year: year, month: month + 1, calendar: cal)
        else { return nil }

        if first > now {
            let priorMonth = month == 1 ? (year - 1, 12) : (year, month - 1)
            guard let previous = cycleStart(day: day, year: priorMonth.0,
                                            month: priorMonth.1, calendar: cal) else { return nil }
            return (previous, first)
        }
        return (first, next)
    }

    private static func cycleStart(day: Int, year: Int, month: Int,
                                   calendar: Calendar) -> Date? {
        let normalizedYear = year + (month - 1) / 12
        let normalizedMonth = ((month - 1) % 12 + 12) % 12 + 1
        guard let first = calendar.date(from: DateComponents(year: normalizedYear,
                                                              month: normalizedMonth, day: 1)),
              let days = calendar.range(of: .day, in: .month, for: first) else { return nil }
        return calendar.date(from: DateComponents(year: normalizedYear,
                                                   month: normalizedMonth,
                                                   day: min(day, days.count)))
    }

    private static func validLimit(_ value: Double?) -> Double? {
        guard let value, value.isFinite, value > 0 else { return nil }
        return value
    }

    private static func validDay(_ value: Int?) -> Int? {
        guard let value, (1...31).contains(value) else { return nil }
        return value
    }
}

// MARK: - Net worth

enum NetWorth {
    /// One already base-converted account. `included` is false for hidden and
    /// archived accounts: their history stays, but they are not money the user
    /// can see or spend today. The signed balance is the only input: a card
    /// overpayment is an asset, card debt reduces net worth, and a negative
    /// cash balance is debt too.
    struct Account: Equatable {
        let balance: Double
        let included: Bool

        init(balance: Double, included: Bool = true) {
            self.balance = balance
            self.included = included
        }
    }

    private static func cents(_ accounts: [Account],
                              _ part: (Double) -> Double) -> Decimal {
        accounts.filter(\.included).reduce(0) { sum, account in
            let value = part(account.balance)
            return sum + (value.isFinite ? Money.cents(value) : 0)
        }
    }

    static func assets(_ accounts: [Account]) -> Double {
        Money.double(cents(accounts) { max(0, $0) })
    }

    static func debt(_ accounts: [Account]) -> Double {
        Money.double(cents(accounts) { max(0, -$0) })
    }

    /// Assets − liabilities, evaluated in cents so the three figures cannot
    /// disagree by a rounding tail.
    static func total(_ accounts: [Account]) -> Double {
        Money.double(cents(accounts) { $0 })
    }
}
