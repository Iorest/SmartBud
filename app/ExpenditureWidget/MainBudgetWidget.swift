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
        let loaded = loadData()

        return makeEntry(from: loaded)
    }

    func getSnapshot(in _: Context, completion: @escaping (MainBudgetWidgetEntry) -> Void) {
        let loaded = loadData()

        let entry = makeEntry(from: loaded)
        completion(entry)
    }

    func getTimeline(in _: Context, completion: @escaping (Timeline<MainBudgetWidgetEntry>) -> Void) {
        let loaded = loadData()

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

    func loadData() -> MainBudgetSnapshot {
        let context = ModelContext(WidgetModelContainer.shared)

        let budgetDescriptor = FetchDescriptor<MainBudgetModel>()
        guard let budget = try? context.fetch(budgetDescriptor).first else {
            return MainBudgetSnapshot(
                found: false,
                totalSpent: 0,
                budgetAmount: 0,
                percentage: 0,
                type: 0,
                startDate: Date.now
            )
        }

        let budgetStartDate = budget.startDate
        let now = Date.now

        let descriptor = FetchDescriptor<TransactionModel>()
        let allTransactions = (try? context.fetch(descriptor)) ?? []
        let filtered = allTransactions.filter {
            $0.countsAsSpend && $0.wrappedDate >= budgetStartDate && $0.wrappedDate <= now
        }

        let holdingTotal = Money.double(Money.sum(filtered.map(\.wrappedAmount)))

        let percentageOfDays: Double
        let calendar = Calendar.current

        if budget.type == 1 {
            let components = calendar.dateComponents([.minute], from: budget.startDate, to: now)
            percentageOfDays = Double(components.minute ?? 0) / 1440
        } else {
            let components1 = calendar.dateComponents([.day], from: budget.startDate, to: budget.endDate)
            guard let numberOfDays = components1.day, numberOfDays > 0 else {
                return MainBudgetSnapshot(found: true, totalSpent: holdingTotal,
                                          budgetAmount: budget.amount, percentage: 0,
                                          type: budget.type, startDate: budget.startDate)
            }

            let components2 = calendar.dateComponents([.day], from: budget.startDate, to: now)
            let numberOfDaysPast = components2.day ?? 0

            percentageOfDays = Double(numberOfDaysPast) / Double(numberOfDays)
        }

        return MainBudgetSnapshot(found: true, totalSpent: holdingTotal,
                                  budgetAmount: budget.amount, percentage: percentageOfDays,
                                  type: budget.type, startDate: budget.startDate)
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
