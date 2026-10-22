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
            var cal = calendar
            cal.firstWeekday = UserDefaults.appGroup.integer(forKey: "firstWeekday")
            cal.minimumDaysInFirstWeek = 4
            let dateComponents = cal.dateComponents([.weekOfYear, .yearForWeekOfYear], from: now)
            startDate = cal.date(from: dateComponents)!
        case .month:
            let dateComponents = calendar.dateComponents([.month, .year], from: now)
            startDate = calendar.date(from: dateComponents)!
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
            let filtered = allTxns.filter { $0.income && $0.wrappedDate >= startDate && $0.wrappedDate <= now }
            return Money.double(Money.sum(filtered.map(\.amount)))

        case .expense:
            let allTxns = (try? context.fetch(FetchDescriptor<TransactionModel>())) ?? []
            let filtered = allTxns.filter { $0.countsAsSpend && $0.wrappedDate >= startDate && $0.wrappedDate <= now }
            return Money.double(Money.sum(filtered.map(\.amount)))

        default:
            return 0
        }
    }

    func loadTransactions(type: TimePeriod, count: Int) -> [HoldingTransaction] {
        let context = ModelContext(WidgetModelContainer.shared)
        let now = Date.now

        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = UserDefaults.appGroup.integer(forKey: "firstWeekday")
        calendar.minimumDaysInFirstWeek = 4

        let startDate: Date
        switch type {
        case .day: startDate = calendar.startOfDay(for: now)
        case .week:
            let components = calendar.dateComponents([.weekOfYear, .yearForWeekOfYear], from: now)
            startDate = calendar.date(from: components)!
        case .month:
            let components = calendar.dateComponents([.month, .year], from: now)
            startDate = calendar.date(from: components)!
        case .year:
            let components = calendar.dateComponents([.year], from: now)
            startDate = calendar.date(from: components)!
        default: return []
        }

        let descriptor = FetchDescriptor<TransactionModel>(
            sortBy: [SortDescriptor(\TransactionModel.date, order: .reverse)]
        )
        let allTxns = (try? context.fetch(descriptor)) ?? []
        let filtered = allTxns.filter { $0.wrappedDate >= startDate && $0.wrappedDate <= now }
        let limited = Array(filtered.prefix(count))

        return limited.map { txn in
            HoldingTransaction(colour: txn.wrappedColour, note: txn.wrappedNote,
                               amount: txn.wrappedAmount, income: txn.income)
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
