//
//  AppPeriod.swift
//  smartbud
//
//  One definition of "this week / this month / this year" for the whole app.
//
//  The user can move the start of the month (payday cycles): with `startDay`
//  at 15, the October bucket runs from 15 Sep to 15 Oct. Log, Insights and the
//  widgets all ask this type instead of each rolling their own calendar maths —
//  they used to disagree, so one expense fell into different months depending
//  on which screen you looked at.
//

import Foundation

enum AppPeriod {

    /// First and last (exclusive) instant of the month bucket containing `date`.
    static func monthRange(
        containing date: Date,
        startDay: Int,
        calendar: Calendar
    ) -> (start: Date, end: Date) {
        let start = monthStart(containing: date, startDay: startDay, calendar: calendar)
        let end = calendar.date(byAdding: .month, value: 1, to: start)
            ?? start.addingTimeInterval(30 * 86_400)
        return (start, end)
    }

    /// Start of the month bucket containing `date`.
    ///
    /// `startDay` is clamped to 1…28 so it exists in every month; the settings
    /// screen offers the same range.
    static func monthStart(
        containing date: Date,
        startDay: Int,
        calendar: Calendar
    ) -> Date {
        let day = max(1, min(startDay, 28))
        let startOfDay = calendar.startOfDay(for: date)
        guard day > 1 else {
            let comps = calendar.dateComponents([.year, .month], from: startOfDay)
            return calendar.date(from: comps) ?? startOfDay
        }

        let comps = calendar.dateComponents([.year, .month, .day], from: startOfDay)
        let currentDay = comps.day ?? day
        var anchor = comps
        anchor.day = day

        if currentDay >= day {
            return calendar.date(from: anchor) ?? startOfDay
        }
        // Before the anchor day: the bucket started in the previous month.
        guard let previousMonth = calendar.date(byAdding: .month, value: -1, to: startOfDay) else {
            return startOfDay
        }
        var previous = calendar.dateComponents([.year, .month], from: previousMonth)
        previous.day = day
        return calendar.date(from: previous) ?? startOfDay
    }

    /// Week bucket containing `date`, respecting `calendar.firstWeekday`.
    static func weekRange(
        containing date: Date,
        calendar: Calendar
    ) -> (start: Date, end: Date) {
        let comps = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        let start = calendar.date(from: comps) ?? calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 7, to: start) ?? start
        return (start, end)
    }

    /// Calendar year containing `date`.
    static func yearRange(
        containing date: Date,
        calendar: Calendar
    ) -> (start: Date, end: Date) {
        let comps = calendar.dateComponents([.year], from: date)
        let start = calendar.date(from: comps) ?? calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .year, value: 1, to: start) ?? start
        return (start, end)
    }

    /// Whole days covered by `range`. Used as the divisor for "average per day"
    /// and as the number of bars in the monthly chart, so a 15th-to-15th period
    /// gets 30/31 bars instead of the calendar month's count.
    static func dayCount(in range: (start: Date, end: Date), calendar: Calendar) -> Int {
        let days = calendar.dateComponents([.day], from: range.start, to: range.end).day ?? 0
        return max(1, days)
    }

    /// One ledger row's contribution to a calendar day. Values are base
    /// currency amounts at the model boundary: `spend` is signed (a refund
    /// is negative), `income` is non-zero only for income rows.
    struct Entry {
        let date: Date
        let spend: Double
        let income: Double
    }

    /// A cell in the period calendar. `hasEntries` distinguishes a day with
    /// only zero-valued rows from a day with no rows at all; both use the same
    /// zero totals so the day sums equal the period totals.
    struct DayTotals: Identifiable, Equatable {
        let date: Date
        let spend: Decimal
        let income: Decimal
        let hasEntries: Bool

        var id: Date { date }
    }

    /// Buckets entries by day across a period, including the empty days
    /// between them. One pass over the entries and one over the days, so a
    /// large ledger costs O(entries + days) rather than O(entries × days).
    static func dayTotals(
        in range: (start: Date, end: Date),
        entries: [Entry],
        calendar: Calendar
    ) -> [DayTotals] {
        var byDay: [Date: (spend: Decimal, income: Decimal, hasEntries: Bool)] = [:]
        for entry in entries {
            guard entry.date >= range.start, entry.date < range.end else { continue }
            let key = calendar.startOfDay(for: entry.date)
            var bucket = byDay[key] ?? (0, 0, false)
            bucket.spend += Money.cents(entry.spend)
            bucket.income += Money.cents(entry.income)
            bucket.hasEntries = true
            byDay[key] = bucket
        }

        var result = [DayTotals]()
        var cursor = calendar.startOfDay(for: range.start)
        while cursor < range.end {
            let bucket = byDay[cursor] ?? (0, 0, false)
            result.append(DayTotals(date: cursor, spend: bucket.spend,
                                    income: bucket.income, hasEntries: bucket.hasEntries))
            // Guard against a calendar that refuses to advance (it would
            // otherwise spin forever building the grid).
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor),
                  next > cursor else { break }
            cursor = next
        }
        return result
    }

    /// Calendar with the user's first-weekday preference applied.
    static func configuredCalendar(firstWeekday: Int) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = firstWeekday > 0 ? firstWeekday : 1
        calendar.minimumDaysInFirstWeek = 4
        // Without this the short weekday/month symbols come back in English
        // even when the app is running in Chinese (the chart axis read
        // "S M T W T F S").
        calendar.locale = Locale.appLocale
        return calendar
    }
}
