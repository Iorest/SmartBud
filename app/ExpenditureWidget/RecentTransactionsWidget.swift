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
        let selected = BookSelection.current()
        return makeEntry(duration: .week, type: .net, selected: selected)
    }

    private func makeEntry(duration: TimePeriod, type: InsightsType, selected: UUID) -> RecentWidgetEntry {
        RecentWidgetEntry(
            date: Date(),
            amount: loadAmount(type: duration, insightsType: type, selected: selected),
            transactions: loadTransactions(type: duration, count: 9, selected: selected),
            duration: duration,
            type: type
        )
    }

    func snapshot(for configuration: RecentWidgetConfigurationIntent, in _: Context) async -> RecentWidgetEntry {
        // The widget process reads the selection from the App Group defaults,
        // so it stays in step with the app without an extra notification.
        let selected = BookSelection.current()
        return makeEntry(duration: configuration.duration, type: configuration.insightsType, selected: selected)
    }

    func timeline(for configuration: RecentWidgetConfigurationIntent, in _: Context) async -> Timeline<Entry> {
        let selected = BookSelection.current()
        let entry = makeEntry(duration: configuration.duration, type: configuration.insightsType, selected: selected)

        let timeline = Timeline(entries: [entry], policy: .atEnd)

        return timeline
    }

    func loadAmount(type: TimePeriod, insightsType: InsightsType, selected: UUID) -> Double {
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
            let allTxns = BookScope.scoped(
                (try? context.fetch(FetchDescriptor<TransactionModel>())) ?? [], \.bookID, selected: selected)
            let filtered = allTxns.filter { $0.wrappedDate >= startDate && $0.wrappedDate <= now }
            return Money.double(Money.sum(filtered.map(\.signedBaseAmount)))

        case .income:
            let allTxns = BookScope.scoped(
                (try? context.fetch(FetchDescriptor<TransactionModel>())) ?? [], \.bookID, selected: selected)
            // `income` alone includes reimbursement repayments, which the app
            // deliberately keeps out of earnings.
            let filtered = allTxns.filter { $0.countsAsIncome && $0.wrappedDate >= startDate && $0.wrappedDate <= now }
            return Money.double(Money.sum(filtered.map(\.wrappedBaseAmount)))

        case .expense:
            let allTxns = BookScope.scoped(
                (try? context.fetch(FetchDescriptor<TransactionModel>())) ?? [], \.bookID, selected: selected)
            let filtered = allTxns.filter {
                ($0.countsAsSpend || $0.isRefund) && $0.wrappedDate >= startDate && $0.wrappedDate <= now
            }
            return Money.double(Money.sum(filtered.map(\.spendBaseAmount)))

        default:
            return 0
        }
    }

    func loadTransactions(type: TimePeriod, count: Int, selected: UUID) -> [HoldingTransaction] {
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
        let allTxns = BookScope.scoped(
            (try? context.fetch(descriptor)) ?? [], \.bookID, selected: selected)
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
