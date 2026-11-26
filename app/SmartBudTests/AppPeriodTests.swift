//
//  AppPeriodTests.swift
//  SmartBudTests
//
//  The month bucket can start on any day 1…28 (Settings → Time Frames). Log,
//  Insights and the widgets all ask `AppPeriod` for it; these tests pin the
//  boundaries so a shifted month never silently overlaps or skips days.
//

import Testing
import Foundation

@Suite("AppPeriod")
struct AppPeriodTests {

    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        cal.firstWeekday = 2   // Monday
        cal.minimumDaysInFirstWeek = 4
        return cal
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    private func start(_ year: Int, _ month: Int, _ day: Int) -> Date {
        date(year, month, day, hour: 0)
    }

    @Test("Month start day 1 is the calendar month")
    func plainMonth() {
        let range = AppPeriod.monthRange(containing: date(2026, 10, 20), startDay: 1, calendar: calendar)
        #expect(range.start == start(2026, 10, 1))
        #expect(range.end == start(2026, 11, 1))
        #expect(AppPeriod.dayCount(in: range, calendar: calendar) == 31)
    }

    @Test("Before the start day the bucket belongs to the previous month")
    func beforeStartDay() {
        let range = AppPeriod.monthRange(containing: date(2026, 10, 10), startDay: 15, calendar: calendar)
        #expect(range.start == start(2026, 9, 15))
        #expect(range.end == start(2026, 10, 15))
        #expect(AppPeriod.dayCount(in: range, calendar: calendar) == 30)
    }

    @Test("On or after the start day the bucket is the current month")
    func afterStartDay() {
        let range = AppPeriod.monthRange(containing: date(2026, 10, 20), startDay: 15, calendar: calendar)
        #expect(range.start == start(2026, 10, 15))
        #expect(range.end == start(2026, 11, 15))
        #expect(AppPeriod.dayCount(in: range, calendar: calendar) == 31)
    }

    @Test("A 28th start day still works in February")
    func endOfFebruary() {
        let before = AppPeriod.monthRange(containing: date(2026, 2, 27), startDay: 28, calendar: calendar)
        #expect(before.start == start(2026, 1, 28))
        #expect(before.end == start(2026, 2, 28))
        #expect(AppPeriod.dayCount(in: before, calendar: calendar) == 31)

        let after = AppPeriod.monthRange(containing: date(2026, 3, 1), startDay: 28, calendar: calendar)
        #expect(after.start == start(2026, 2, 28))
        #expect(after.end == start(2026, 3, 28))
        #expect(AppPeriod.dayCount(in: after, calendar: calendar) == 28)
    }

    @Test("Leap February keeps its 29 days")
    func leapFebruary() {
        let range = AppPeriod.monthRange(containing: date(2028, 2, 10), startDay: 1, calendar: calendar)
        #expect(range.start == start(2028, 2, 1))
        #expect(range.end == start(2028, 3, 1))
        #expect(AppPeriod.dayCount(in: range, calendar: calendar) == 29)
    }

    @Test("Start day is clamped to 1…28")
    func clampsStartDay() {
        let zero = AppPeriod.monthRange(containing: date(2026, 10, 20), startDay: 0, calendar: calendar)
        #expect(zero.start == start(2026, 10, 1))

        // 40 clamps to 28; 20 Oct is before the 28th, so the bucket opened on
        // 28 Sep.
        let huge = AppPeriod.monthRange(containing: date(2026, 10, 20), startDay: 40, calendar: calendar)
        #expect(huge.start == start(2026, 9, 28))
    }

    @Test("Week follows the configured first weekday")
    func week() {
        let range = AppPeriod.weekRange(containing: date(2026, 10, 21), calendar: calendar)
        #expect(range.start == start(2026, 10, 19))   // Monday
        #expect(range.end == start(2026, 10, 26))
    }

    @Test("Year is the calendar year")
    func year() {
        let range = AppPeriod.yearRange(containing: date(2026, 10, 21), calendar: calendar)
        #expect(range.start == start(2026, 1, 1))
        #expect(range.end == start(2027, 1, 1))
    }

    @Test("Consecutive months share no day and skip none")
    func monthsTileTheYear() {
        var cursor = start(2026, 1, 15)
        var covered = 0
        for _ in 0..<12 {
            let range = AppPeriod.monthRange(containing: cursor, startDay: 15, calendar: calendar)
            #expect(range.start == cursor)
            covered += AppPeriod.dayCount(in: range, calendar: calendar)
            cursor = range.end
        }
        #expect(covered == 365)
        #expect(cursor == start(2027, 1, 15))
    }

    @Test("Calendar days cover the month bucket and sum to the period totals")
    func calendarDaysMatchPeriod() {
        let range = AppPeriod.monthRange(containing: date(2026, 10, 20),
                                         startDay: 1, calendar: calendar)
        let entries = [
            AppPeriod.Entry(date: date(2026, 10, 1), spend: 12.5, income: 0),
            AppPeriod.Entry(date: date(2026, 10, 1, hour: 20), spend: 0, income: 100),
            AppPeriod.Entry(date: date(2026, 10, 31, hour: 23), spend: 7.25, income: 0),
            AppPeriod.Entry(date: date(2026, 9, 30), spend: 999, income: 0),
            AppPeriod.Entry(date: date(2026, 11, 1), spend: 999, income: 0)
        ]

        let days = AppPeriod.dayTotals(in: range, entries: entries, calendar: calendar)
        #expect(days.count == 31)
        #expect(days.first?.date == start(2026, 10, 1))
        #expect(days.last?.date == start(2026, 10, 31))
        #expect(days[0].spend == Decimal(string: "12.5")!)
        #expect(days[0].income == 100)
        #expect(days[0].hasEntries)
        #expect(days[1].spend == 0)
        #expect(days[1].income == 0)
        #expect(!days[1].hasEntries)
        #expect(days[30].spend == Decimal(string: "7.25")!)
        #expect(days.reduce(Decimal.zero) { $0 + $1.spend } == Decimal(string: "19.75")!)
        #expect(days.reduce(Decimal.zero) { $0 + $1.income } == 100)
    }

    @Test("A shifted month calendar crosses the calendar-month line")
    func calendarDaysAcrossMonths() {
        let range = AppPeriod.monthRange(containing: date(2026, 10, 10),
                                         startDay: 15, calendar: calendar)
        let entries = [
            AppPeriod.Entry(date: date(2026, 9, 14), spend: 500, income: 0),
            AppPeriod.Entry(date: date(2026, 9, 15), spend: 4, income: 0),
            AppPeriod.Entry(date: date(2026, 10, 14), spend: 0, income: 6),
            AppPeriod.Entry(date: date(2026, 10, 15), spend: 500, income: 0)
        ]

        let days = AppPeriod.dayTotals(in: range, entries: entries, calendar: calendar)
        #expect(days.count == 30)
        #expect(days.first?.date == start(2026, 9, 15))
        #expect(days.last?.date == start(2026, 10, 14))
        #expect(days[0].spend == 4)
        #expect(days[29].income == 6)
        #expect(days.reduce(Decimal.zero) { $0 + $1.spend } == 4)
        #expect(days.reduce(Decimal.zero) { $0 + $1.income } == 6)
    }

    @Test("Refunds reduce the day's spend, never its income")
    func calendarRefundIsNegativeSpend() {
        let range = AppPeriod.monthRange(containing: date(2026, 10, 20),
                                         startDay: 1, calendar: calendar)
        let entries = [
            AppPeriod.Entry(date: date(2026, 10, 5), spend: 20, income: 0),
            AppPeriod.Entry(date: date(2026, 10, 5, hour: 15), spend: -8.5, income: 0)
        ]
        let days = AppPeriod.dayTotals(in: range, entries: entries, calendar: calendar)
        #expect(days[4].spend == Decimal(string: "11.5")!)
        #expect(days[4].income == 0)
        #expect(days.reduce(Decimal.zero) { $0 + $1.spend } == Decimal(string: "11.5")!)
    }

    @Test("A thousand entries keep their day buckets and exact total")
    func calendarThousandEntries() {
        let range = AppPeriod.monthRange(containing: date(2026, 10, 20),
                                         startDay: 1, calendar: calendar)
        let entries = (0..<1000).map { index -> AppPeriod.Entry in
            AppPeriod.Entry(date: date(2026, 10, 1 + index % 30, hour: 8 + index % 12),
                            spend: Double(index % 7) + 0.1,
                            income: index % 50 == 0 ? 3 : 0)
        }

        let days = AppPeriod.dayTotals(in: range, entries: entries, calendar: calendar)
        #expect(days.count == 31)
        #expect(days.filter(\.hasEntries).count == 30)
        #expect(days.reduce(Decimal.zero) { $0 + $1.spend } == Money.sum(entries.map(\.spend)))
        #expect(days.reduce(Decimal.zero) { $0 + $1.income } == Money.sum(entries.map(\.income)))
    }
}
