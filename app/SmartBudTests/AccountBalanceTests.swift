//
//  AccountBalanceTests.swift
//  SmartBudTests
//
//  T5: the balance-adjustment invariant. `AccountViewModel.adjustBalance`
//  writes one dedicated row; after it lands the derived balance must equal the
//  target. The delta formula lives in `AccountBalance` so the invariant can be
//  pinned on Linux without a SwiftData container or the rate store.
//

import Testing
import Foundation

@Suite("Balance adjustment invariant")
struct BalanceAdjustmentInvariantTests {

    /// Applies the adjustment row the same way `adjustBalance` does and
    /// recomputes the balance from the opening amount and all rows.
    private func adjusted(opening: Double,
                          target: Double,
                          existing: [(amount: Double, income: Bool, isRefund: Bool)] = []) -> Double? {
        let current = AccountBalance.current(opening: opening, transactions: existing)
        guard let delta = AccountBalance.adjustmentDelta(target: target, current: current) else { return nil }
        var rows = existing
        rows.append((amount: abs(delta), income: delta > 0, isRefund: false))
        return AccountBalance.current(opening: opening, transactions: rows)
    }

    @Test("A positive delta brings the balance up to the target")
    func increases() throws {
        let balance = try #require(adjusted(opening: 100, target: 125.5))
        #expect(Money.cents(balance) == Money.cents(125.5))
        #expect(AccountBalance.adjustmentDelta(target: 125.5, current: 100) == 25.5)
    }

    @Test("A negative delta brings the balance down to the target")
    func decreases() throws {
        let balance = try #require(adjusted(opening: 100, target: 70))
        #expect(Money.cents(balance) == Money.cents(70))
        #expect(AccountBalance.adjustmentDelta(target: 70, current: 100) == -30)
    }

    @Test("Refunds already counted as income are not double counted")
    func keepsExistingRefund() throws {
        let rows: [(amount: Double, income: Bool, isRefund: Bool)] = [
            (amount: 15, income: false, isRefund: true)
        ]
        let balance = try #require(adjusted(opening: 100, target: 125, existing: rows))
        #expect(Money.cents(balance) == Money.cents(125))
        // The refund moved the balance up, so only 10 is added.
        #expect(AccountBalance.adjustmentDelta(target: 125, current: 115) == 10)
    }

    @Test("An already matching balance writes no adjustment row")
    func noRowWhenEqual() {
        #expect(adjusted(opening: 100, target: 100) == nil)
        // Sub-cent differences are not a real change: amounts are stored to cents.
        #expect(AccountBalance.adjustmentDelta(target: 100.004, current: 100) == nil)
    }

    @Test("Binary float noise does not create a phantom adjustment")
    func ignoresFloatTail() {
        #expect(AccountBalance.adjustmentDelta(target: 100.3, current: 100.299_999_999) == nil)
    }

    @Test("Non-finite amounts are refused instead of trapping the Decimal conversion")
    func refusesNonFinite() {
        #expect(AccountBalance.adjustmentDelta(target: .infinity, current: 100) == nil)
        #expect(AccountBalance.adjustmentDelta(target: .nan, current: 100) == nil)
        #expect(AccountBalance.adjustmentDelta(target: 100, current: .infinity) == nil)
    }
}

// MARK: - Credit cards and net worth

@Suite("Credit card balance and net worth")
struct CreditCardLedgerTests {
    @Test("Card spend then transfer repayment returns to zero with one expense row")
    func repaymentIsTransferNotExpense() {
        let cardRows = [(amount: 100.0, income: false, isRefund: false)]
        let afterSpend = AccountBalance.current(opening: 0, transactions: cardRows)
        let afterRepayment = AccountBalance.current(opening: 0, transactions: cardRows,
                                                    transfersIn: 100)
        #expect(afterSpend == -100)
        #expect(afterRepayment == 0)
        #expect(cardRows.filter { !$0.income && !$0.isRefund }.count == 1)
        #expect(Money.cents(cardRows.reduce(0) { $0 + $1.amount }) == Money.cents(100))
    }

    @Test("Available credit follows the signed balance; overpayment is not usage")
    func availableCredit() throws {
        let normal = try #require(CreditCard.usage(limit: 5000, balance: -100, cycleSpend: 100))
        #expect(normal.used == 100)
        #expect(normal.available == 4900)
        #expect(normal.dueThisCycle == 100)
        #expect(!normal.isOverLimit)

        let over = try #require(CreditCard.usage(limit: 5000, balance: -6000, cycleSpend: 6000))
        #expect(over.used == 6000)
        #expect(over.available == -1000)
        #expect(over.isOverLimit)

        // Overpaid card: no usage, more headroom, nothing to pay this cycle.
        let overpaid = try #require(CreditCard.usage(limit: 5000, balance: 100, cycleSpend: 100))
        #expect(overpaid.used == 0)
        #expect(overpaid.available == 5100)
        #expect(overpaid.dueThisCycle == 0)
        #expect(!overpaid.isOverLimit)

        #expect(CreditCard.usage(limit: nil, balance: -100, cycleSpend: 100) == nil)
    }

    @Test("An overpaid card warns at its real limit, not limit plus twice the overpayment")
    func overpaidCardWarningUsesRealLimit() throws {
        let balance = 1000.0
        let usage = try #require(CreditCard.usage(limit: 5000, balance: balance, cycleSpend: 0))
        #expect(usage.limit == 5000)
        #expect(usage.available == 6000)
        // Reconstructing the limit from used + available yields 6000 here,
        // which moves the warning threshold to 7000 and misses 6001.
        #expect(usage.used + usage.available == 6000)

        func legacyWouldExceed(_ amount: Double) -> Bool {
            balance - amount < -(usage.used + usage.available)
        }
        func wouldExceed(_ amount: Double) -> Bool { balance - amount < -usage.limit }
        #expect(!legacyWouldExceed(6001))
        #expect(!wouldExceed(6000))
        #expect(wouldExceed(6001))
    }

    @Test("The statement cycle starts on the statement day and rolls monthly")
    func statementCycle() throws {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(secondsFromGMT: 0)!
        let formatter = ISO8601DateFormatter()
        let before = try #require(formatter.date(from: "2026-11-24T12:00:00Z"))
        let after = try #require(formatter.date(from: "2026-11-25T12:00:00Z"))

        let previous = try #require(CreditCard.cycle(statementDay: 25, at: before, calendar: utc))
        #expect(previous.start == formatter.date(from: "2026-10-25T00:00:00Z"))
        #expect(previous.end == formatter.date(from: "2026-11-25T00:00:00Z"))

        let current = try #require(CreditCard.cycle(statementDay: 25, at: after, calendar: utc))
        #expect(current.start == formatter.date(from: "2026-11-25T00:00:00Z"))
        #expect(current.end == formatter.date(from: "2026-12-25T00:00:00Z"))
        #expect(CreditCard.cycle(statementDay: nil, at: after, calendar: utc) == nil)
    }

    @Test("Net worth counts overpaid cards as assets and excludes hidden/archived")
    func netWorth() {
        let mixed: [NetWorth.Account] = [
            .init(balance: 1000),                  // cash
            .init(balance: 500, included: false),  // hidden cash
            .init(balance: -300),                  // card debt
            .init(balance: -200, included: false)  // archived card debt
        ]
        #expect(NetWorth.assets(mixed) == 1000)
        #expect(NetWorth.debt(mixed) == 300)
        #expect(NetWorth.total(mixed) == 700)

        // 100 overpaid on a card is an asset, not negative debt.
        let overpaid: [NetWorth.Account] = [
            .init(balance: 1000),
            .init(balance: 100)
        ]
        #expect(NetWorth.assets(overpaid) == 1100)
        #expect(NetWorth.debt(overpaid) == 0)
        #expect(NetWorth.total(overpaid) == 1100)

        // A single card with a positive balance used to report -100.
        let onlyCard: [NetWorth.Account] = [.init(balance: 100)]
        #expect(NetWorth.total(onlyCard) == 100)
        #expect(NetWorth.total([]) == 0)
        #expect(NetWorth.assets(mixed) - NetWorth.debt(mixed) == NetWorth.total(mixed))
    }

    @Test("Credit fields are clamped and cleared on non-credit accounts")
    func sanitizesTerms() {
        let card = CreditCard.sanitized(limit: 5000, statementDay: 25, dueDay: 40, kind: 2)
        #expect(card.limit == 5000)
        #expect(card.statementDay == 25)
        #expect(card.dueDay == nil)

        let bad = CreditCard.sanitized(limit: -1, statementDay: 0, dueDay: 3, kind: 2)
        #expect(bad.limit == nil)
        #expect(bad.statementDay == nil)

        let debit = CreditCard.sanitized(limit: 5000, statementDay: 25, dueDay: 3, kind: 1)
        #expect(debit.limit == nil)
        #expect(debit.statementDay == nil)
        #expect(debit.dueDay == nil)
    }
}
