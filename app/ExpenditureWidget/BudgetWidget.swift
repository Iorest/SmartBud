//
//  BudgetWidget.swift
//  smartbud
//
//  Created by Iorest on 17/8/22.
//

import SwiftUI
import WidgetKit
import SwiftData

struct BudgetWidget: Widget {
    let kind: String = "BudgetWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: BudgetWidgetConfigurationIntent.self,
            provider: BudgetWidgetProvider()) { entry in
            BudgetWidgetEntryView(entry: entry)
                .environment(\.locale, Locale.appLocale)
        }
        .configurationDisplayName("Budget")
        .description("Monitor how you are sticking to your budgets.")
        .supportedFamilies([.systemSmall])
    }
}

struct WidgetBudgetSnapshot {
    let total: Double
    let percentage: Double
    let budget: HoldingBudget
}

struct BudgetWidgetProvider: AppIntentTimelineProvider {
    typealias Intent = BudgetWidgetConfigurationIntent

    public typealias Entry = BudgetWidgetEntry

    func placeholder(in _: Context) -> BudgetWidgetEntry {
        let loaded = loadData(budgetId: "")

        return BudgetWidgetEntry(
            date: Date(),
            totalSpent: loaded.total,
            percentageOfDays: loaded.percentage,
            budget: loaded.budget,
            configuration: BudgetWidgetConfigurationIntent()
        )
    }

    func snapshot(for configuration: BudgetWidgetConfigurationIntent, in _: Context) async -> BudgetWidgetEntry {
        let loaded = loadData(budgetId: configuration.budget?.id.uuidString ?? "")

        return BudgetWidgetEntry(
            date: Date(),
            totalSpent: loaded.total,
            percentageOfDays: loaded.percentage,
            budget: loaded.budget,
            configuration: configuration
        )
    }

    func timeline(for configuration: BudgetWidgetConfigurationIntent, in _: Context) async -> Timeline<Entry> {
        let loaded = loadData(budgetId: configuration.budget?.id.uuidString ?? "")

        let entry = BudgetWidgetEntry(
            date: Date(),
            totalSpent: loaded.total,
            percentageOfDays: loaded.percentage,
            budget: loaded.budget,
            configuration: configuration
        )

        let timeline = Timeline(entries: [entry], policy: .atEnd)

        return timeline
    }

    func loadData(budgetId: String) -> WidgetBudgetSnapshot {
        let context = ModelContext(WidgetModelContainer.shared)

        guard let uuid = UUID(uuidString: budgetId) else {
            let budget = HoldingBudget(type: 1, emoji: "failed", name: "", colour: "", budgetAmount: 0)
            return WidgetBudgetSnapshot(total: 0, percentage: 0, budget: budget)
        }

        let fetchId = uuid
        var budgetDesc = FetchDescriptor<BudgetModel>()
        budgetDesc.fetchLimit = 1

        let allBudgets = (try? context.fetch(budgetDesc)) ?? []
        guard let budgetModel = allBudgets.first(where: { $0.id == fetchId }) else {
            let budget = HoldingBudget(type: 1, emoji: "failed", name: "", colour: "", budgetAmount: 0)
            return WidgetBudgetSnapshot(total: 0, percentage: 0, budget: budget)
        }

        let budgetStartDate = budgetModel.startDate
        let budgetCategory = budgetModel.category
        let now = Date.now

        let txnDesc = FetchDescriptor<TransactionModel>()
        let allTransactions = (try? context.fetch(txnDesc)) ?? []
        let filtered = allTransactions.filter {
            !$0.income
                && $0.wrappedDate >= budgetStartDate
                && $0.wrappedDate <= now
                && $0.category?.id == budgetCategory?.id
        }

        let holdingTotal = Money.double(Money.sum(filtered.map(\.wrappedAmount)))

        let returnBudget = HoldingBudget(
            type: budgetModel.type,
            emoji: budgetModel.wrappedEmoji,
            name: budgetModel.wrappedName,
            colour: budgetModel.wrappedColour,
            budgetAmount: budgetModel.amount
        )

        let percentageOfDays: Double
        let calendar = Calendar.current

        if budgetModel.type == 1 {
            let components = calendar.dateComponents([.minute], from: budgetModel.startDate, to: now)
            percentageOfDays = Double(components.minute ?? 0) / 1440
        } else {
            let components1 = calendar.dateComponents([.day], from: budgetModel.startDate, to: budgetModel.endDate)
            guard let numberOfDays = components1.day, numberOfDays > 0 else {
                return WidgetBudgetSnapshot(total: holdingTotal, percentage: 0, budget: returnBudget)
            }

            let components2 = calendar.dateComponents([.day], from: budgetModel.startDate, to: now)
            let numberOfDaysPast = components2.day ?? 0

            percentageOfDays = Double(numberOfDaysPast) / Double(numberOfDays)
        }

        return WidgetBudgetSnapshot(total: holdingTotal, percentage: percentageOfDays, budget: returnBudget)
    }
}

struct BudgetWidgetEntry: TimelineEntry {
    let date: Date
    let totalSpent: Double
    let percentageOfDays: Double
    let budget: HoldingBudget
    let configuration: BudgetWidgetConfigurationIntent
}

struct HoldingBudget {
    let type: Int
    let emoji: String
    let name: String
    let colour: String
    let budgetAmount: Double
}

struct BudgetWidgetEntryView: View {
    let entry: BudgetWidgetProvider.Entry

    var budgetType: String {
        switch entry.budget.type {
        case 1:
            return String.appLocalized("today")
        case 2:
            return String.appLocalized("this week")
        case 3:
            return String.appLocalized("this month")
        case 4:
            return String.appLocalized("this year")
        default:
            return String.appLocalized("this week")
        }
    }

    var difference: Double {
        return abs(entry.budget.budgetAmount - entry.totalSpent)
    }

    var percentString1: String {
        return "\(Int(round((entry.totalSpent / entry.budget.budgetAmount) * 100)))%"
    }

    var systemSmallWidgetText: String {
        if entry.budget.budgetAmount >= entry.totalSpent {
            return String(localized: "left \(budgetType)")
        } else {
            return String(localized: "over \(budgetType)")
        }
    }

    func showTimeFrame(size: CGFloat) -> Bool {
        return size > systemSmallWidgetText.widthOfRoundedString(size: 10, weight: .semibold)
    }

    var body: some View {
        if entry.configuration.budget == nil {
            Text(String.appLocalized("Select budget in widget options"))
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundColor(Color.SubtitleText)
                .padding(15)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .containerBackground(for: .widget) {
                    WidgetGlassBackground()
                }

        } else if entry.budget.emoji == "failed" {
            Text(String.appLocalized("Budget no longer exists - please select new budget from widget options."))
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundColor(Color.SubtitleText)
                .padding(15)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .containerBackground(for: .widget) {
                    WidgetGlassBackground()
                }

        } else {
            VStack(spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2.4) {
                        HStack(spacing: 5) {
                            Text(entry.budget.emoji)
                                .font(.system(size: 9))
                            Text(entry.budget.name.uppercased())
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .lineLimit(1)
                        }
                        .foregroundColor(Color.PrimaryText)

                        Text(String(localized: "SPENT: \(percentString1)"))
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundColor(Color.SubtitleText)
                    }

                    Spacer()

                    RingView(
                        percent: entry.percentageOfDays,
                        width: 2.4,
                        topStroke: Color.DarkBackground,
                        bottomStroke: Color.SecondaryBackground
                    )
                        .frame(width: 13, height: 13)
                        .padding(3)
                }
                .frame(maxWidth: .infinity)

                GeometryReader { proxy in
                    VStack(spacing: 6) {
                        ZStack(alignment: .bottom) {
                            ZStack {
                                DonutSemicircle(percent: 1, cornerRadius: 4, width: 15)
                                    .fill(Color.SecondaryBackground)
                                    .frame(width: proxy.size.width, height: proxy.size.width / 2)

                                if entry.totalSpent / entry.budget.budgetAmount < 0.97 {
                                    DonutSemicircle(
                                        percent: 1 - (entry.totalSpent / entry.budget.budgetAmount),
                                        cornerRadius: 4,
                                        width: 15
                                    )
                                        .fill(Color(hex: entry.budget.colour))
                                        .frame(width: proxy.size.width, height: proxy.size.width / 2)
                                }
                            }
                            .frame(width: proxy.size.width)

                            VStack(spacing: -4) {
                                WidgetBudgetDollarView(
                                    amount: difference,
                                    red: entry.totalSpent >= entry.budget.budgetAmount
                                )
                                    .frame(width: proxy.size.width - 50)

                                if showTimeFrame(size: proxy.size.width - 50) {
                                    Text(systemSmallWidgetText)
                                        .font(.system(size: 10, weight: .medium, design: .rounded))
                                        .foregroundColor(Color.SubtitleText)
                                } else {
                                    if entry.budget.budgetAmount >= entry.totalSpent {
                                        Text(String.appLocalized("left"))
                                            .font(.system(size: 10, weight: .medium, design: .rounded))
                                            .foregroundColor(Color.SubtitleText)
                                    } else {
                                        Text(String.appLocalized("over"))
                                            .font(.system(size: 10, weight: .medium, design: .rounded))
                                            .foregroundColor(Color.SubtitleText)
                                    }
                                }
                            }
                        }
                        .frame(width: proxy.size.width)

                        HStack {
                            if entry.totalSpent > 999.99 || entry.budget.budgetAmount > 999.99 {
                                Text("\(Int(round(entry.totalSpent)))")
                                    .frame(width: 50, alignment: .leading)
                                Spacer()
                                Text("\(Int(round(entry.budget.budgetAmount)))")
                                    .frame(width: 50, alignment: .trailing)
                            } else {
                                Text("\(entry.totalSpent, specifier: "%.2f")")
                                    .frame(width: 50, alignment: .leading)
                                Spacer()
                                Text("\(entry.budget.budgetAmount, specifier: "%.2f")")
                                    .frame(width: 50, alignment: .trailing)
                            }
                        }
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundColor(Color.SubtitleText)
                    }
                    .frame(width: proxy.size.width, height: proxy.size.height, alignment: .bottom)
                }
                .frame(maxHeight: .infinity, alignment: .bottom)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .containerBackground(for: .widget) {
                WidgetGlassBackground()
            }
            .widgetURL(budgetDeepLink(entry.budget.name))
        }
    }
}

struct WidgetBudgetDollarView: View {
    @AppStorage("showCents", store: .appGroup) var showCents: Bool = true

    var amount: Double
    var red: Bool

    @AppStorage("currency", store: .appGroup) var currency: String = Locale.current.currency?.identifier ?? "USD"
    var currencySymbol: String {
        return Locale.appCurrencySymbol(forCurrencyCode: currency)
    }

    var body: some View {
        HStack(alignment: .lastTextBaseline, spacing: 1.3) {
            Text(currencySymbol)
                .font(.system(.subheadline, design: .rounded).weight(.medium))
                .foregroundColor(red ? Color("BudgetRed") : Color.SubtitleText)

            Text("\(amount, specifier: showCents && amount < 100  ? "%.2f" : "%.0f")")
                .font(.system(.title3, design: .rounded).weight(.medium))
                .foregroundColor(red ? Color("BudgetRed") : Color.PrimaryText)

        }
        .minimumScaleFactor(0.5)
        .lineLimit(1)
    }
}
