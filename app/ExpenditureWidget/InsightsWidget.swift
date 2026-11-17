//
//  InsightsWidget.swift
//  smartbud
//
//  Created by Iorest on 14/8/22.
//

import Foundation
import SwiftUI
import WidgetKit
import SwiftData

struct InsightsWidget: Widget {
    let kind: String = "InsightsWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: InsightsWidgetConfigurationIntent.self,
            provider: InsightsProvider()) { entry in
            InsightsWidgetEntryView(entry: entry)
                .environment(\.locale, Locale.appLocale)
        }
        .configurationDisplayName("Insights")
        .description("Analyse your expenditure breakdowns over various time periods.")
        .supportedFamilies([.systemMedium])
    }
}

/// Everything the widget renders. Replaces a seven-member tuple so the
/// provider's signature stays readable (and SwiftLint-legal).
struct InsightsSnapshot {
    let amount: Double
    let maximum: Double
    let average: Double
    let numberOfDays: Int
    let dates: [Date]
    let dateDictionary: [Date: Double]
    let categories: [HoldingCategory]

    static let empty = InsightsSnapshot(amount: 0, maximum: 0, average: 0, numberOfDays: 0,
                                        dates: [], dateDictionary: [:], categories: [])
}

/// Start date and bucket shape for one of the three periods.
private struct PeriodSpec {
    let startDate: Date
    let step: Calendar.Component
    let value: Int
    let count: Int
    /// Unit used for the "average per ..." divisor.
    let elapsedUnit: Calendar.Component
}

/// One bucket series: daily for week/month, monthly for year.
private struct BucketSeries {
    let total: Double
    let maximum: Double
    let activeDays: Int
    let dates: [Date]
    let byDate: [Date: Double]
}

struct InsightsProvider: AppIntentTimelineProvider {
    typealias Intent = InsightsWidgetConfigurationIntent

    public typealias Entry = InsightsWidgetEntry

    func placeholder(in _: Context) -> InsightsWidgetEntry {
        makeEntry(from: loadData(type: .week, income: true), duration: .week, income: true)
    }

    func snapshot(for configuration: InsightsWidgetConfigurationIntent, in _: Context) async -> InsightsWidgetEntry {
        let income = configuration.income == .income
        return makeEntry(from: loadData(type: configuration.duration, income: income),
                         duration: configuration.duration, income: income)
    }

    func timeline(for configuration: InsightsWidgetConfigurationIntent, in _: Context) async -> Timeline<Entry> {
        let income = configuration.income == .income
        let entry = makeEntry(from: loadData(type: configuration.duration, income: income),
                              duration: configuration.duration, income: income)
        return Timeline(entries: [entry], policy: .atEnd)
    }

    private func makeEntry(from data: InsightsSnapshot,
                           duration: InsightsTimePeriod,
                           income: Bool) -> InsightsWidgetEntry {
        InsightsWidgetEntry(
            date: Date(),
            amount: data.amount,
            duration: duration,
            maximum: data.maximum,
            dates: data.dates,
            dictionary: data.dateDictionary,
            numberOfDays: data.numberOfDays,
            average: data.average,
            categories: data.categories,
            income: income
        )
    }

    func loadData(type: InsightsTimePeriod, income: Bool) -> InsightsSnapshot {
        let context = ModelContext(WidgetModelContainer.shared)
        let now = Date.now
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = UserDefaults.appGroup.integer(forKey: "firstWeekday")
        calendar.minimumDaysInFirstWeek = 4

        guard let period = periodSpec(type: type, now: now, calendar: calendar) else {
            return .empty
        }

        let allTransactions = (try? context.fetch(FetchDescriptor<TransactionModel>())) ?? []
        let transactions = allTransactions.filter {
            let counted = income ? $0.countsAsIncome : ($0.countsAsSpend || $0.isRefund)
            return counted && $0.wrappedDate >= period.startDate && $0.wrappedDate <= now
        }
        let allCategories = (try? context.fetch(FetchDescriptor<CategoryModel>())) ?? []
        let categories = allCategories.filter { $0.income == income }

        let series = bucketSeries(for: transactions, period: period, calendar: calendar, income: income)
        let elapsed = Calendar.current.dateComponents([period.elapsedUnit],
                                                      from: period.startDate, to: now)
        let divisor = (elapsed.value(for: period.elapsedUnit) ?? 0) + 1

        return InsightsSnapshot(
            amount: series.total,
            maximum: series.maximum,
            average: series.total / Double(divisor),
            numberOfDays: series.activeDays,
            dates: series.dates,
            dateDictionary: series.byDate,
            categories: categoryBreakdown(transactions: transactions,
                                          categories: categories,
                                          total: series.total,
                                          income: income)
        )
    }

    private func periodSpec(type: InsightsTimePeriod, now: Date,
                            calendar: Calendar) -> PeriodSpec? {
        switch type {
        case .week:
            let comps = calendar.dateComponents([.weekOfYear, .yearForWeekOfYear], from: now)
            guard let start = calendar.date(from: comps) else { return nil }
            return PeriodSpec(startDate: start, step: .day, value: 1,
                              count: 7, elapsedUnit: .day)
        case .month:
            let startDay = UserDefaults.appGroup.integer(forKey: "firstDayOfMonth")
            let range = AppPeriod.monthRange(containing: now, startDay: startDay, calendar: calendar)
            return PeriodSpec(startDate: range.start, step: .day, value: 1,
                              count: AppPeriod.dayCount(in: range, calendar: calendar),
                              elapsedUnit: .day)
        case .year:
            let comps = calendar.dateComponents([.year], from: now)
            guard let start = calendar.date(from: comps) else { return nil }
            return PeriodSpec(startDate: start, step: .month, value: 1,
                              count: 12, elapsedUnit: .month)
        case .unknown:
            return nil
        }
    }

    private func bucketSeries(for transactions: [TransactionModel],
                              period: PeriodSpec,
                              calendar: Calendar,
                              income: Bool) -> BucketSeries {
        var dates: [Date] = []
        var byDate: [Date: Double] = [:]
        var total = 0.0
        var maximum = 0.0
        var activeDays = 0
        var cursor = period.startDate

        for _ in 0..<period.count {
            let next = calendar.date(byAdding: period.step, value: period.value, to: cursor) ?? cursor
            let bucket = transactions
                .filter { $0.wrappedDate >= cursor && $0.wrappedDate < next }
                .reduce(0.0) { $0 + (income ? $1.wrappedBaseAmount : $1.spendBaseAmount) }
            // The bar cannot draw below zero; the total still carries the
            // refund so the headline matches the app's net figure.
            let bar = max(0, bucket)

            total += bucket
            byDate[cursor] = bar
            maximum = max(maximum, bar)
            if bar != 0 { activeDays += 1 }
            dates.append(cursor)
            cursor = next
        }

        return BucketSeries(total: total, maximum: maximum, activeDays: activeDays,
                            dates: dates, byDate: byDate)
    }

    private func categoryBreakdown(transactions: [TransactionModel],
                                   categories: [CategoryModel],
                                   total: Double,
                                   income: Bool) -> [HoldingCategory] {
        guard total > 0 else { return [] }
        return categories.compactMap { category in
            // Refunds net out of their category; a category fully refunded
            // has no share of the total to show.
            let amount = transactions
                .filter { $0.category == category }
                .reduce(0.0) { $0 + (income ? $1.wrappedBaseAmount : $1.spendBaseAmount) }
            guard amount > 0 else { return nil }
            return HoldingCategory(colour: category.wrappedColour,
                                   name: category.wrappedName,
                                   percent: amount / total)
        }
        .sorted { $0.percent > $1.percent }
    }
}

struct InsightsWidgetEntry: TimelineEntry {
    let date: Date
    let amount: Double
    let duration: InsightsTimePeriod
    let maximum: Double
    let dates: [Date]
    let dictionary: [Date: Double]
    let numberOfDays: Int
    let average: Double
    let categories: [HoldingCategory]
    let income: Bool
}
