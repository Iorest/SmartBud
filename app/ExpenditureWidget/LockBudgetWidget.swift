//
//  LockBudgetWidget.swift
//  ExpenditureWidgetExtension
//
//  Created by Iorest on 9/9/22.
//

import SwiftUI
import WidgetKit
import SwiftData

struct LockBudgetWidget: Widget {
    let kind: String = "LockBudgetWidget"

    private let supportedFamilies: [WidgetFamily] = [
        .accessoryCircular,
        .accessoryRectangular,
        .accessoryInline
    ]

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: BudgetWidgetConfigurationIntent.self,
            provider: LockBudgetWidgetProvider()) { entry in
            LockBudgetWidgetEntryView(entry: entry)
                .environment(\.locale, Locale.appLocale)
        }
        .configurationDisplayName("Budget")
        .description("Monitor how you are sticking to your budgets.")
        .supportedFamilies(supportedFamilies)
    }
}

struct LockBudgetSnapshot {
    let total: Double
    let timeLeft: String
    let budget: HoldingBudget
}

struct LockBudgetWidgetProvider: AppIntentTimelineProvider {
    typealias Intent = BudgetWidgetConfigurationIntent

    public typealias Entry = LockBudgetWidgetEntry

    func placeholder(in _: Context) -> LockBudgetWidgetEntry {
        let loaded = loadData(budgetId: "")

        return LockBudgetWidgetEntry(
            date: Date(),
            totalSpent: loaded.total,
            timeLeft: loaded.timeLeft,
            budget: loaded.budget,
            configuration: BudgetWidgetConfigurationIntent()
        )
    }

    func snapshot(for configuration: BudgetWidgetConfigurationIntent, in _: Context) async -> LockBudgetWidgetEntry {
        let loaded = loadData(budgetId: configuration.budget?.id.uuidString ?? "")

        let entry = LockBudgetWidgetEntry(
            date: Date(),
            totalSpent: loaded.total,
            timeLeft: loaded.timeLeft,
            budget: loaded.budget,
            configuration: configuration
        )
        return entry
    }

    func timeline(for configuration: BudgetWidgetConfigurationIntent, in _: Context) async -> Timeline<Entry> {
        let loaded = loadData(budgetId: configuration.budget?.id.uuidString ?? "")

        let entry = LockBudgetWidgetEntry(
            date: Date(),
            totalSpent: loaded.total,
            timeLeft: loaded.timeLeft,
            budget: loaded.budget,
            configuration: configuration
        )

        let timeline = Timeline(entries: [entry], policy: .atEnd)

        return timeline
    }

    func loadData(budgetId: String) -> LockBudgetSnapshot {
        let context = ModelContext(WidgetModelContainer.shared)

        guard let uuid = UUID(uuidString: budgetId) else {
            let budget = HoldingBudget(type: 1, emoji: "failed", name: "", colour: "", budgetAmount: 0)
            return LockBudgetSnapshot(total: 0, timeLeft: "", budget: budget)
        }

        let fetchId = uuid
        // `fetchLimit = 1` + `first(where:)` used to return nil as soon as
        // the user had more than one budget; filter in the store instead.
        let budgetDesc = FetchDescriptor<BudgetModel>(predicate: #Predicate { $0.id == fetchId })
        guard let budgetModel = (try? context.fetch(budgetDesc))?.first else {
            let budget = HoldingBudget(type: 1, emoji: "failed", name: "", colour: "", budgetAmount: 0)
            return LockBudgetSnapshot(total: 0, timeLeft: "", budget: budget)
        }

        // The stored start only rolls when the budget screen opens; derive
        // the current period here so the widget never sums last week's rows.
        let budgetStartDate = BudgetRollover.roll(startDate: budgetModel.startDate,
                                                  type: budgetModel.type) ?? budgetModel.startDate
        let budgetCategory = budgetModel.category
        let now = Date.now
        let allTxns = (try? context.fetch(FetchDescriptor<TransactionModel>())) ?? []
        let filteredTxns = allTxns.filter {
            guard let categoryID = budgetCategory?.id else { return false }
            return ($0.countsAsSpend || $0.isRefund)
                && $0.wrappedDate >= budgetStartDate
                && $0.wrappedDate <= now
                && $0.category?.id == categoryID
        }

        let holdingTotal = Money.double(Money.sum(filteredTxns.map(\.spendBaseAmount)))

        let returnBudget = HoldingBudget(
            type: budgetModel.type,
            emoji: budgetModel.wrappedEmoji,
            name: budgetModel.wrappedName,
            colour: budgetModel.wrappedColour,
            budgetAmount: budgetModel.amount
        )

        let timeLeft = Self.timeLeftLabel(for: budgetModel, now: now)

        return LockBudgetSnapshot(total: holdingTotal, timeLeft: timeLeft, budget: returnBudget)
    }

    /// "5 days left" copy for the accessory widgets.
    private static func timeLeftLabel(for budget: BudgetModel, now: Date) -> String {
        let calendar = Calendar.current
        if budget.type == 1 {
            let components = calendar.dateComponents([.hour], from: budget.startDate, to: now)
            return String(localized: "^[\(max(0, 24 - (components.hour ?? 0))) hours left](inflect: true)")
        }
        if budget.type == 2 {
            let components = calendar.dateComponents([.day], from: budget.startDate, to: now)
            return String(localized: "^[\(max(0, 7 - (components.day ?? 0))) days left](inflect: true)")
        }
        let total = calendar.dateComponents([.day], from: budget.startDate, to: budget.endDate).day ?? 0
        let past = calendar.dateComponents([.day], from: budget.startDate, to: now).day ?? 0
        return String(localized: "^[\(max(0, Int(total - past))) days left](inflect: true)")
    }
}

struct LockBudgetWidgetEntry: TimelineEntry {
    let date: Date
    let totalSpent: Double
    let timeLeft: String
    let budget: HoldingBudget
    let configuration: BudgetWidgetConfigurationIntent
}

struct LockBudgetWidgetEntryView: View {
    @Environment(\.widgetFamily) var widgetFamily
    let entry: LockBudgetWidgetProvider.Entry

    var budgetType: String {
        budgetPeriodLabel(entry.budget.type)
    }

    var subtitle: String {
        if entry.budget.budgetAmount > entry.totalSpent {
            return String.appLocalized("left")
        } else {
            return String.appLocalized("over")
        }
    }

    var difference: Double {
        return abs(entry.budget.budgetAmount - entry.totalSpent)
    }

    /// The provider hands back a `"failed"` placeholder when the configured
    /// budget was deleted; both states must fall back to the picker prompt.
    private var isPlaceholder: Bool {
        entry.configuration.budget == nil || entry.budget.emoji == "failed"
    }

    var percent: Double {
        Money.spendFraction(entry.totalSpent, of: entry.budget.budgetAmount)
    }

    var percentString: String {
        return String.appFormatted("%lld%% spent", Int(round(percent * 100)))
    }

    @AppStorage("currency", store: .appGroup) var currency: String = Locale.current.currency?.identifier ?? "USD"
    var currencySymbol: String {
        return Locale.appCurrencySymbol(forCurrencyCode: currency)
    }

    @AppStorage("showCents", store: .appGroup) var showCents: Bool = true
    /// Lock Screen widgets are visible without unlocking. Defaults to hiding
    /// amounts; the spent percentage still tells the user where they stand.
    @AppStorage("hideLockWidgetAmounts", store: .appGroup) var hideAmounts: Bool = true

    var body: some View {
        switch widgetFamily {
        case .accessoryInline:
            if isPlaceholder {
                Text(String.appLocalized("Select budget in widget options"))
            } else {
                if hideAmounts {
                    Text("\(entry.budget.emoji) \(percentString)")
                        .widgetURL(budgetDeepLink(entry.budget.name))
                } else {
                    let amount = amountText(difference, showCents: showCents)
                    Text("\(entry.budget.emoji) \(currencySymbol)\(amount) \(subtitle)")
                        .widgetURL(budgetDeepLink(entry.budget.name))
                }
            }

        case .accessoryCircular:
            if isPlaceholder {
                ZStack {
                    AccessoryWidgetBackground()

                    Text(String.appLocalized("SELECT BUDGET"))
                        .font(.system(size: 8, weight: .semibold, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                }
                .containerBackground(for: .widget) { AccessoryWidgetBackground() }
            } else {
                Gauge(value: min(max(percent, 0), 1)) {
                    Text(entry.budget.emoji)
                } currentValueLabel: {
                    Text("\(Int(round(percent * 100)))%")
                }
                .gaugeStyle(AccessoryCircularGaugeStyle())
                .widgetURL(budgetDeepLink(entry.budget.name))
                .containerBackground(for: .widget) { Color.clear }
            }

        case .accessoryRectangular:
            if isPlaceholder {
                Text(String.appLocalized("SELECT BUDGET IN WIDGET OPTIONS"))
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                    .containerBackground(for: .widget) { Color.clear }
            } else {
                GeometryReader { proxy in
                    VStack(alignment: .leading) {
                        HStack(spacing: 3) {
                            Text(entry.budget.name)

                            if showPercent(size: proxy.size.width) {
                                Text(String.appLocalized("•"))
                                Text(percentString)
                            }
                        }
                        .font(.system(size: 15, weight: .semibold, design: .rounded))

                        if hideAmounts {
                            Text("\(percentString) \(budgetType)")
                                .font(.system(size: 14, weight: .regular, design: .rounded))
                                .foregroundStyle(Color.SubtitleText)
                        } else {
                            let amount = amountText(difference, showCents: showCents)
                            Text("\(currencySymbol)\(amount) \(subtitle) \(budgetType)")
                                .font(.system(size: 14, weight: .regular, design: .rounded))
                                .foregroundStyle(Color.SubtitleText)
                        }

                        Gauge(value: min(max(percent, 0), 1), in: 0 ... 1) {
                            Text(String.appLocalized("Percent Spent"))
                        } currentValueLabel: {
                            EmptyView()
                        } minimumValueLabel: {
                            if !hideAmounts {
                                Text(amountText(entry.totalSpent, showCents: showCents))
                                    .font(.system(size: 10, weight: .regular, design: .rounded))
                            }
                        } maximumValueLabel: {
                            if !hideAmounts {
                                Text(amountText(entry.budget.budgetAmount, showCents: showCents))
                                    .font(.system(size: 10, weight: .regular, design: .rounded))
                            }
                        }
                        .frame(height: 5)
                        .gaugeStyle(.accessoryLinear)
                    }
                    .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .widgetURL(budgetDeepLink(entry.budget.name))
                .containerBackground(for: .widget) { Color.clear }
            }

        default:
            EmptyView()
        }
    }

    func showPercent(size: CGFloat) -> Bool {
        return size > entry
            .budget
            .name
            .widthOfRoundedString(size: 15, weight: .semibold) + 15 + percentString
            .widthOfRoundedString(size: 15, weight: .semibold)
    }
}
