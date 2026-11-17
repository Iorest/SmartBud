//
//  RecentTransactionsWidget.swift
//  ExpenditureWidgetExtension
//
//  Created by Iorest on 12/8/22.
//

import SwiftUI
import WidgetKit
import SwiftData

struct RecentExpenditureWidget: Widget {
    let kind: String = "ExpenditureWidget"

    private let supportedFamilies: [WidgetFamily] = [
        .accessoryRectangular,
        .accessoryInline,
        .systemSmall,
        .systemLarge
    ]

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: RecentWidgetConfigurationIntent.self,
            provider: Provider()) { entry in
            ExpenditureWidgetEntryView(entry: entry)
                .environment(\.locale, Locale.appLocale)
        }
        .configurationDisplayName("Recent Transactions")
        .description("View your latest expenses.")
        .supportedFamilies(supportedFamilies)
    }
}

struct Provider: AppIntentTimelineProvider {
    typealias Intent = RecentWidgetConfigurationIntent

    public typealias Entry = RecentWidgetEntry

    func placeholder(in _: Context) -> RecentWidgetEntry {
        makeEntry(duration: .week, type: .net)
    }

    private func makeEntry(duration: TimePeriod, type: InsightsType) -> RecentWidgetEntry {
        RecentWidgetEntry(
            date: Date(),
            amount: loadAmount(type: duration, insightsType: type),
            transactions: loadTransactions(type: duration, count: 9),
            duration: duration,
            type: type
        )
    }

    func snapshot(for configuration: RecentWidgetConfigurationIntent, in _: Context) async -> RecentWidgetEntry {
        let entry = makeEntry(duration: configuration.duration, type: configuration.insightsType)
        return entry
    }

    func timeline(for configuration: RecentWidgetConfigurationIntent, in _: Context) async -> Timeline<Entry> {
        let entry = makeEntry(duration: configuration.duration, type: configuration.insightsType)

        let timeline = Timeline(entries: [entry], policy: .atEnd)

        return timeline
    }

    func loadAmount(type: TimePeriod, insightsType: InsightsType) -> Double {
        let context = ModelContext(WidgetModelContainer.shared)
        let now = Date.now
        let calendar = Calendar(identifier: .gregorian)

        let startDate: Date

        switch type {
        case .day:
            startDate = calendar.startOfDay(for: now)
        case .week:
            let cal = AppPeriod.configuredCalendar(
                firstWeekday: UserDefaults.appGroup.integer(forKey: "firstWeekday"))
            startDate = AppPeriod.weekRange(containing: now, calendar: cal).start
        case .month:
            // "This month" honours the user's payday-style start day; the
            // insights and log screens use the same boundaries.
            startDate = AppPeriod.monthStart(
                containing: now,
                startDay: UserDefaults.appGroup.integer(forKey: "firstDayOfMonth"),
                calendar: calendar)
        case .year:
            let dateComponents = calendar.dateComponents([.year], from: now)
            startDate = calendar.date(from: dateComponents)!
        default:
            return 0
        }

        switch insightsType {
        case .net:
            let allTxns = (try? context.fetch(FetchDescriptor<TransactionModel>())) ?? []
            let filtered = allTxns.filter { $0.wrappedDate >= startDate && $0.wrappedDate <= now }
            return Money.double(Money.sum(filtered.map(\.signedBaseAmount)))

        case .income:
            let allTxns = (try? context.fetch(FetchDescriptor<TransactionModel>())) ?? []
            // `income` alone includes reimbursement repayments, which the app
            // deliberately keeps out of earnings.
            let filtered = allTxns.filter { $0.countsAsIncome && $0.wrappedDate >= startDate && $0.wrappedDate <= now }
            return Money.double(Money.sum(filtered.map(\.wrappedBaseAmount)))

        case .expense:
            let allTxns = (try? context.fetch(FetchDescriptor<TransactionModel>())) ?? []
            let filtered = allTxns.filter {
                ($0.countsAsSpend || $0.isRefund) && $0.wrappedDate >= startDate && $0.wrappedDate <= now
            }
            return Money.double(Money.sum(filtered.map(\.spendBaseAmount)))

        default:
            return 0
        }
    }

    func loadTransactions(type: TimePeriod, count: Int) -> [HoldingTransaction] {
        let context = ModelContext(WidgetModelContainer.shared)
        let now = Date.now

        let calendar = AppPeriod.configuredCalendar(
            firstWeekday: UserDefaults.appGroup.integer(forKey: "firstWeekday"))

        let startDate: Date
        switch type {
        case .day: startDate = calendar.startOfDay(for: now)
        case .week:
            startDate = AppPeriod.weekRange(containing: now, calendar: calendar).start
        case .month:
            startDate = AppPeriod.monthStart(
                containing: now,
                startDay: UserDefaults.appGroup.integer(forKey: "firstDayOfMonth"),
                calendar: calendar)
        case .year:
            startDate = AppPeriod.yearRange(containing: now, calendar: calendar).start
        default: return []
        }

        let descriptor = FetchDescriptor<TransactionModel>(
            sortBy: [SortDescriptor(\TransactionModel.date, order: .reverse)]
        )
        let allTxns = (try? context.fetch(descriptor)) ?? []
        let filtered = allTxns.filter { $0.wrappedDate >= startDate && $0.wrappedDate <= now }
        let limited = Array(filtered.prefix(count))

        return limited.map { txn in
            // A refund returns money, so it renders on the incoming side even
            // though `income` is false (it is not earnings).
            HoldingTransaction(colour: txn.wrappedColour, note: txn.wrappedNote,
                               amount: txn.wrappedBaseAmount,
                               income: txn.income || txn.isRefund)
        }
    }
}

struct RecentWidgetEntry: TimelineEntry {
    let date: Date
    let amount: Double
    let transactions: [HoldingTransaction]
    let duration: TimePeriod
    let type: InsightsType
}

struct HoldingTransaction: Hashable {
    let colour: String
    let note: String
    let amount: Double
    let income: Bool
}
