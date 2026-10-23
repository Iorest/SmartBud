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
