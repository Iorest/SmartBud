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
