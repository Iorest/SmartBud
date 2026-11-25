//
//  MainBudgetWidget.swift
//  smartbud
//
//  Created by Iorest on 12/1/23.
//

import SwiftUI
import WidgetKit
import SwiftData

struct MainBudgetWidget: Widget {
    let kind: String = "MainBudgetWidget"

    private var supportedFamilies: [WidgetFamily] {
        return [.accessoryCircular, .accessoryRectangular, .systemSmall]
    }

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MainBudgetWidgetProvider()) { entry in
            MainBudgetWidgetEntryView(entry: entry)
                .environment(\.locale, Locale.appLocale)
        }
        .supportedFamilies(supportedFamilies)
        .configurationDisplayName("Overall Budget")
        .description("Monitor how you are sticking to your overall budgets.")
    }
}

struct MainBudgetSnapshot {
    let found: Bool
    let totalSpent: Double
    let budgetAmount: Double
    let percentage: Double
    let type: Int
    let startDate: Date
}

struct MainBudgetWidgetProvider: TimelineProvider {
    typealias Entry = MainBudgetWidgetEntry

    func placeholder(in _: Context) -> MainBudgetWidgetEntry {
        let selected = BookSelection.current()
        let loaded = loadData(selected: selected)
        return makeEntry(from: loaded)
    }

    func getSnapshot(in _: Context, completion: @escaping (MainBudgetWidgetEntry) -> Void) {
        let selected = BookSelection.current()
        let loaded = loadData(selected: selected)
        let entry = makeEntry(from: loaded)
        completion(entry)
    }

    func getTimeline(in _: Context, completion: @escaping (Timeline<MainBudgetWidgetEntry>) -> Void) {
        // One selection per timeline keeps the overall budget and its spend
        // rows in the same book, even if the app switches while we load.
        let selected = BookSelection.current()
        let loaded = loadData(selected: selected)
        let entry = makeEntry(from: loaded)

        let timeline = Timeline(entries: [entry], policy: .atEnd)

        completion(timeline)
    }

    private func makeEntry(from data: MainBudgetSnapshot) -> MainBudgetWidgetEntry {
        MainBudgetWidgetEntry(
            date: Date(),
            totalSpent: data.totalSpent,
            percentageOfDays: data.percentage,
            type: data.type,
            budgetAmount: data.budgetAmount,
            startDate: data.startDate,
            found: data.found
        )
    }

    func loadData(selected: UUID) -> MainBudgetSnapshot {
        let context = ModelContext(WidgetModelContainer.shared)

        let budgetDescriptor = FetchDescriptor<MainBudgetModel>()
        let budgets = (try? context.fetch(budgetDescriptor)) ?? []
        guard let budget = budgets.first(where: { BookScope.matches($0.bookID, selected: selected) }) else {
            return MainBudgetSnapshot(
                found: false,
                totalSpent: 0,
                budgetAmount: 0,
                percentage: 0,
                type: 0,
                startDate: Date.now
            )
        }

        // The stored start only rolls when the budget screen opens; derive
        // the current period here so the widget never sums last week's rows.
        let budgetStartDate = BudgetRollover.roll(startDate: budget.startDate,
                                                  type: budget.type) ?? budget.startDate
        let now = Date.now

        let descriptor = FetchDescriptor<TransactionModel>()
        let allTransactions = BookScope.scoped((try? context.fetch(descriptor)) ?? [], \.bookID, selected: selected)
        let filtered = allTransactions.filter {
            ($0.countsAsSpend || $0.isRefund) && $0.wrappedDate >= budgetStartDate && $0.wrappedDate <= now
        }

        let holdingTotal = Money.double(Money.sum(filtered.map(\.spendBaseAmount)))

        let percentageOfDays: Double
        let calendar = Calendar.current

        if budget.type == 1 {
            let components = calendar.dateComponents([.minute], from: budgetStartDate, to: now)
            percentageOfDays = Double(components.minute ?? 0) / 1440
        } else {
            let periodEnd = BudgetPeriod.endDate(from: budgetStartDate, type: budget.type)
            let components1 = calendar.dateComponents([.day], from: budgetStartDate, to: periodEnd)
            guard let numberOfDays = components1.day, numberOfDays > 0 else {
                return MainBudgetSnapshot(found: true, totalSpent: holdingTotal,
                                          budgetAmount: budget.amount, percentage: 0,
                                          type: budget.type, startDate: budgetStartDate)
            }

            let components2 = calendar.dateComponents([.day], from: budgetStartDate, to: now)
            let numberOfDaysPast = components2.day ?? 0

            percentageOfDays = Double(numberOfDaysPast) / Double(numberOfDays)
        }

        return MainBudgetSnapshot(found: true, totalSpent: holdingTotal,
                                  budgetAmount: budget.amount, percentage: percentageOfDays,
                                  type: budget.type, startDate: budgetStartDate)
    }
}

struct MainBudgetWidgetEntry: TimelineEntry {
    let date: Date
    let totalSpent: Double
    let percentageOfDays: Double
    let type: Int
    let budgetAmount: Double
    let startDate: Date
    let found: Bool
}
