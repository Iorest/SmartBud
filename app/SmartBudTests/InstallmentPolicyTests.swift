//
//  InstallmentPolicyTests.swift
//  SmartBudTests
//
//  The money rules of an installment plan that need no SwiftData: cent-exact
//  totals, the last-period remainder and the credit-restore cap. Runs in the
//  Linux harness as well as the macOS suite. Amounts are compared as cents:
//  the stored Double can carry a binary tail (33.339999… for 33.34).
//

import Testing
import Foundation

@Suite("Installment policy")
struct InstallmentPolicyTests {

    private func cents(_ values: [Double]) -> [Decimal] { values.map(Money.cents) }

    @Test("Twelve periods add up to the plan principal to the cent")
    func twelvePeriodPrincipal() {
        let rows = InstallmentPolicy.schedule(principal: 12_345.67, fee: 0, periods: 12,
                                              firstDate: Date(timeIntervalSince1970: 0))
        #expect(rows.count == 12)
        #expect(Money.sum(rows.map(\.principal)) == Money.cents(12_345.67))
        #expect(rows.allSatisfy { Money.cents($0.fee) == 0 })
    }

    @Test("Fee is split to the cent and never folded into principal")
    func feeSplit() {
        let rows = InstallmentPolicy.schedule(principal: 1_200, fee: 96.30, periods: 12,
                                              firstDate: Date(timeIntervalSince1970: 0))
        #expect(Money.sum(rows.map(\.principal)) == Money.cents(1_200))
        #expect(Money.sum(rows.map(\.fee)) == Money.cents(96.30))
        #expect(rows.allSatisfy { Money.cents($0.principal) == Money.cents(100) })
        #expect(rows.dropLast().allSatisfy { Money.cents($0.fee) == Money.cents(8.02) })
        #expect(rows.last.map { Money.cents($0.fee) } == Money.cents(8.08))
    }

    @Test("The last period absorbs the whole remainder")
    func finalRemainder() {
        let rows = InstallmentPolicy.schedule(principal: 100, fee: 0.10, periods: 3,
                                              firstDate: Date(timeIntervalSince1970: 0))
        #expect(cents(rows.map(\.principal)) == [33.33, 33.33, 33.34].map(Money.cents))
        #expect(cents(rows.map(\.fee)) == [0.03, 0.03, 0.04].map(Money.cents))
        #expect(Money.sum(rows.map(\.principal)) == Money.cents(100))
        #expect(Money.sum(rows.map(\.fee)) == Money.cents(0.10))
    }

    @Test("A cent-scale plan still sums exactly")
    func subCentPlan() {
        let rows = InstallmentPolicy.schedule(principal: 0.05, fee: 0.01, periods: 3,
                                              firstDate: Date(timeIntervalSince1970: 0))
        #expect(cents(rows.map(\.principal)) == [0.01, 0.01, 0.03].map(Money.cents))
        #expect(Money.sum(rows.map(\.principal)) == Money.cents(0.05))
    }

    @Test("Dates advance one month per period")
    func monthlyDates() {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(secondsFromGMT: 0)!
        let first = utc.date(from: DateComponents(year: 2026, month: 1, day: 15))!
        let rows = InstallmentPolicy.schedule(principal: 12, fee: 0, periods: 3,
                                              firstDate: first, calendar: utc)
        let parts = rows.map { utc.dateComponents([.year, .month, .day], from: $0.date) }
        #expect(parts.map(\.month) == [1, 2, 3])
        #expect(parts.allSatisfy { $0.day == 15 })
    }

    @Test("Restored credit is repaid principal and never exceeds the plan")
    func restoredLimit() {
        func restored(_ executed: Int) -> Decimal {
            Money.cents(InstallmentPolicy.restoredLimit(principal: 100, periods: 3,
                                                        executed: executed))
        }
        #expect(restored(0) == 0)
        #expect(restored(1) == Money.cents(33.33))
        #expect(restored(2) == Money.cents(66.66))
        #expect(restored(3) == Money.cents(100))
        #expect(restored(99) == Money.cents(100))
        #expect(restored(-2) == 0)
    }

    @Test("Invalid plans are refused before they reach the ledger")
    func validation() {
        #expect(InstallmentPolicy.validate(principal: 100, fee: 0, periods: 12) == nil)
        #expect(InstallmentPolicy.validate(principal: 0, fee: 0, periods: 12) == .nonPositivePrincipal)
        #expect(InstallmentPolicy.validate(principal: -1, fee: 0, periods: 12) == .nonPositivePrincipal)
        #expect(InstallmentPolicy.validate(principal: .nan, fee: 0, periods: 12) == .nonPositivePrincipal)
        #expect(InstallmentPolicy.validate(principal: 100, fee: 0, periods: 0) == .invalidPeriodCount)
        #expect(InstallmentPolicy.validate(principal: 100, fee: -0.01, periods: 12) == .negativeFee)
        #expect(InstallmentPolicy.schedule(principal: 0, fee: 0, periods: 12,
                                           firstDate: .now).isEmpty)
    }
}
