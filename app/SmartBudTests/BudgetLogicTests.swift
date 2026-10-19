//
//  BudgetLogicTests.swift
//  SmartBudTests
//
//  Unit tests for the pure budget rollover / recurrence arithmetic in
//  app/smartbud/Logic/BudgetLogic.swift. The same source file is compiled
//  directly into this test bundle (no app-host), so no import is needed.
//

import Testing
import Foundation

@Suite("BudgetRollover")
struct BudgetRolloverTests {

    private let calendar = Calendar(identifier: .gregorian)

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day,
                                           hour: 0, minute: 0, second: 0))!
    }

    @Test("Invalid type returns nil (endDate == startDate, must not advance)")
    func invalidTypeReturnsNil() {
        #expect(BudgetRollover.roll(startDate: date(2026, 1, 1), type: 0,
                                    now: date(2026, 6, 1)) == nil)
        #expect(BudgetRollover.roll(startDate: date(2026, 1, 1), type: 5,
                                    now: date(2026, 6, 1)) == nil)
    }

    @Test("Monthly budget rolls to the current period")
    func monthlyRoll() {
        let start = BudgetRollover.roll(startDate: date(2026, 1, 1), type: 3,
                                        now: date(2026, 3, 15))
        #expect(start == date(2026, 3, 1))
    }

    @Test("Current period is left untouched")
    func currentPeriodUntouched() {
        let start = date(2026, 3, 1)
        let rolled = BudgetRollover.roll(startDate: start, type: 3,
                                         now: date(2026, 3, 15))
        #expect(rolled == start) // Apr 1 > Mar 15, no roll
    }

    @Test("Daily budget rolls day by day")
    func dailyRoll() {
        let start = BudgetRollover.roll(startDate: date(2026, 3, 1), type: 1,
                                        now: date(2026, 3, 4))
        #expect(start == date(2026, 3, 4))
    }

    @Test("Weekly budget rolls in 7-day steps")
    func weeklyRoll() {
        let start = BudgetRollover.roll(startDate: date(2026, 3, 1), type: 2,
                                        now: date(2026, 3, 20))
        #expect(start == date(2026, 3, 15)) // 1 -> 8 -> 15 (22 > 20, stop)
    }

    @Test("Yearly budget rolls in year steps")
    func yearlyRoll() {
        let start = BudgetRollover.roll(startDate: date(2020, 6, 1), type: 4,
                                        now: date(2026, 3, 1))
        #expect(start == date(2025, 6, 1))
    }

    @Test("Very old start date terminates quickly (regression: former infinite loop)")
    func ancientStartDateTerminates() {
        let start = BudgetRollover.roll(startDate: date(1970, 1, 1), type: 3,
                                        now: date(2026, 3, 15))
        #expect(start != nil)
        // Result must be within one period of `now`.
        let next = calendar.date(byAdding: .month, value: 1, to: start!)
        #expect(next! > date(2026, 3, 15))
    }
}

@Suite("Recurrence")
struct RecurrenceTests {

    private let calendar = Calendar(identifier: .gregorian)

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day,
                                           hour: 0, minute: 0, second: 0))!
    }

    @Test("Zero or negative coefficient returns nil (regression: former infinite loop)")
    func zeroCoefficientReturnsNil() {
        let day = date(2026, 3, 1)
        #expect(Recurrence.nextOccurrence(after: day, type: 1, coefficient: 0) == nil)
        #expect(Recurrence.nextOccurrence(after: day, type: 2, coefficient: 0) == nil)
        #expect(Recurrence.nextOccurrence(after: day, type: 3, coefficient: 0) == nil)
        #expect(Recurrence.nextOccurrence(after: day, type: 1, coefficient: -2) == nil)
    }

    @Test("Unknown type returns nil")
    func unknownTypeReturnsNil() {
        let day = date(2026, 3, 1)
        #expect(Recurrence.nextOccurrence(after: day, type: 0, coefficient: 1) == nil)
        #expect(Recurrence.nextOccurrence(after: day, type: 4, coefficient: 1) == nil)
    }

    @Test("Daily recurrence advances by N days")
    func dailyNext() {
        let next = Recurrence.nextOccurrence(after: date(2026, 3, 1), type: 1, coefficient: 3)
        #expect(next == date(2026, 3, 4))
    }

    @Test("Weekly recurrence advances by N weeks")
    func weeklyNext() {
        let next = Recurrence.nextOccurrence(after: date(2026, 3, 1), type: 2, coefficient: 2)
        #expect(next == date(2026, 3, 15))
    }

    @Test("Monthly recurrence advances by N months")
    func monthlyNext() {
        let next = Recurrence.nextOccurrence(after: date(2026, 1, 31), type: 3, coefficient: 1)
        // Jan 31 + 1 month clamps to Feb 28 in a non-leap year.
        #expect(next == date(2026, 2, 28))
    }
}
