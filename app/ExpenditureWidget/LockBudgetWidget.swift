//
//  LockBudgetWidget.swift
//  ExpenditureWidgetExtension
//
//  Created by Rafael Soh on 9/9/22.
//

import SwiftUI
import WidgetKit
import SwiftData

struct LockBudgetWidget: Widget {
    let kind: String = "LockBudgetWidget"

    private var supportedFamilies: [WidgetFamily] {
        if #available(iOSApplicationExtension 16, *) {
            return [
                .accessoryCircular,
                .accessoryRectangular,
                .accessoryInline
            ]
        } else {
            return [WidgetFamily]()
        }
    }

    var body: some WidgetConfiguration {
        IntentConfiguration(kind: kind, intent: BudgetWidgetConfigurationIntent.self, provider: LockBudgetWidgetProvider()) { entry in
            LockBudgetWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Budget")
        .description("Monitor how you are sticking to your budgets.")
        .supportedFamilies(supportedFamilies)
    }
}

struct LockBudgetWidgetProvider: IntentTimelineProvider {
    typealias Intent = BudgetWidgetConfigurationIntent

    public typealias Entry = LockBudgetWidgetEntry

    nonisolated(unsafe) static let container: ModelContainer = {
        let schema = Schema([
            TransactionModel.self,
            BudgetModel.self,
            CategoryModel.self
        ])
        let config = ModelConfiguration("MainModel", groupContainer: .identifier("group.com.rafaelsoh.dime"))
        return try! ModelContainer(for: schema, configurations: [config])
    }()

    func placeholder(in _: Context) -> LockBudgetWidgetEntry {
        let loaded = loadData(budgetId: "")

        return LockBudgetWidgetEntry(date: Date(), totalSpent: loaded.total, timeLeft: loaded.timeLeft, budget: loaded.budget, configuration: BudgetWidgetConfigurationIntent())
    }

    func getSnapshot(for configuration: BudgetWidgetConfigurationIntent, in _: Context, completion: @escaping (LockBudgetWidgetEntry) -> Void) {
        let loaded = loadData(budgetId: configuration.budget?.identifier ?? "")

        let entry = LockBudgetWidgetEntry(date: Date(), totalSpent: loaded.total, timeLeft: loaded.timeLeft, budget: loaded.budget, configuration: configuration)
        completion(entry)
    }

    func getTimeline(for configuration: BudgetWidgetConfigurationIntent, in _: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        let loaded = loadData(budgetId: configuration.budget?.identifier ?? "")

        let entry = LockBudgetWidgetEntry(date: Date(), totalSpent: loaded.total, timeLeft: loaded.timeLeft, budget: loaded.budget, configuration: configuration)

        let timeline = Timeline(entries: [entry], policy: .atEnd)

        completion(timeline)
    }

    func loadData(budgetId: String) -> (total: Double, timeLeft: String, budget: HoldingBudget) {
        let context = ModelContext(Self.container)

        guard let uuid = UUID(uuidString: budgetId) else {
            let budget = HoldingBudget(type: 1, emoji: "failed", name: "", colour: "", budgetAmount: 0)
            return (0, "", budget)
        }

        let fetchId = uuid
        var budgetDesc = FetchDescriptor<BudgetModel>()
        budgetDesc.fetchLimit = 1
        let allBudgets = (try? context.fetch(budgetDesc)) ?? []
        guard let budgetModel = allBudgets.first(where: { $0.id == fetchId }) else {
            let budget = HoldingBudget(type: 1, emoji: "failed", name: "", colour: "", budgetAmount: 0)
            return (0, "", budget)
        }

        let budgetStartDate = budgetModel.startDate
        let budgetCategory = budgetModel.category
        let now = Date.now
        let allTxns = (try? context.fetch(FetchDescriptor<TransactionModel>())) ?? []
        let filteredTxns = allTxns.filter {
            !$0.income && $0.wrappedDate >= budgetStartDate && $0.wrappedDate <= now && $0.category?.id == budgetCategory?.id
        }

        var holdingTotal = filteredTxns.reduce(0) { $0 + $1.wrappedAmount }

        for transaction in filteredTxns {
            if transaction.category?.id == budgetCategory?.id {
                holdingTotal += transaction.wrappedAmount
            }
        }

        let returnBudget = HoldingBudget(
            type: budgetModel.type,
            emoji: budgetModel.wrappedEmoji,
            name: budgetModel.wrappedName,
            colour: budgetModel.wrappedColour,
            budgetAmount: budgetModel.amount
        )

        let timeLeft: String
        let calendar = Calendar.current

        if budgetModel.type == 1 {
            let components = calendar.dateComponents([.hour], from: budgetModel.startDate, to: now)
            timeLeft = String(localized: "\(24 - (components.hour ?? 0)) hours left")
        } else if budgetModel.type == 2 {
            let components = calendar.dateComponents([.day], from: budgetModel.startDate, to: now)
            timeLeft = String(localized: "\(7 - (components.day ?? 0)) days left")
        } else {
            let components1 = calendar.dateComponents([.day], from: budgetModel.startDate, to: budgetModel.endDate)
            let numberOfDays = components1.day ?? 0

            let components2 = calendar.dateComponents([.day], from: budgetModel.startDate, to: now)
            let numberOfDaysPast = components2.day ?? 0

            let daysLeftNumber = Int(numberOfDays - numberOfDaysPast)
            timeLeft = String(localized: "\(daysLeftNumber) days left")
        }

        return (holdingTotal, timeLeft, returnBudget)
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
        switch entry.budget.type {
        case 1:
            return String(localized: "today")
        case 2:
            return String(localized: "this week")
        case 3:
            return String(localized: "this month")
        case 4:
            return String(localized: "this year")
        default:
            return "this week"
        }
    }

    var subtitle: String {
        if entry.budget.budgetAmount > entry.totalSpent {
            return String(localized: "left")
        } else {
            return String(localized: "over")
        }
    }

    var difference: Double {
        return abs(entry.budget.budgetAmount - entry.totalSpent)
    }

    var percent: Double {
        return entry.totalSpent / entry.budget.budgetAmount
    }

    var percentString: String {
        return String(localized: "\(Int(round((entry.totalSpent / entry.budget.budgetAmount) * 100)))% spent")
    }

    @AppStorage("currency", store: UserDefaults(suiteName: "group.com.rafaelsoh.dime")) var currency: String = Locale.current.currency?.identifier ?? "USD"
    var currencySymbol: String {
        return Locale.current.localizedCurrencySymbol(forCurrencyCode: currency)!
    }

    @AppStorage("showCents", store: UserDefaults(suiteName: "group.com.rafaelsoh.dime")) var showCents: Bool = true

    var body: some View {
        switch widgetFamily {
        case .accessoryInline:
            if entry.configuration.budget == nil {
                Text("Select budget in widget options")
            } else {
                Text("\(entry.budget.emoji) \(currencySymbol)\(difference, specifier: (showCents && difference < 100) ? "%.2f" : "%.0f") \(subtitle)")
                    .widgetURL(URL(string: "dimeapp://budget?budget=\(entry.budget.name)"))
            }

        case .accessoryCircular:
            if #available(iOS 17.0, *) {
                if entry.configuration.budget == nil {
                    ZStack {
                        AccessoryWidgetBackground()

                        Text("SELECT BUDGET")
                            .font(.system(size: 8, weight: .semibold, design: .rounded))
                            .frame(maxWidth: .infinity)
                            .multilineTextAlignment(.center)
                    }
                    .containerBackground(for: .widget) { AccessoryWidgetBackground() }
                } else {
                    Gauge(value: percent < 1 ? percent : 1) {
                        Text(entry.budget.emoji)
                    } currentValueLabel: {
                        Text("\(Int(round(percent * 100)))%")
                    }
                    .gaugeStyle(AccessoryCircularGaugeStyle())
                    .widgetURL(URL(string: "dimeapp://budget?budget=\(entry.budget.name)"))
                    .containerBackground(for: .widget) { Color.clear }
                }
            } else {
                if entry.configuration.budget == nil {
                    ZStack {
                        if #available(iOS 16.0, *) {
                            AccessoryWidgetBackground()
                        }

                        VStack {
                            Text("SELECT BUDGET")
                                .font(.system(size: 8, weight: .semibold, design: .rounded))
                                .frame(maxWidth: .infinity)
                                .multilineTextAlignment(.center)
                        }
                    }
                } else {
                    if #available(iOS 16.0, *) {
                        Gauge(value: percent < 1 ? percent : 1) {
                            Text(entry.budget.emoji)
                        } currentValueLabel: {
                            Text("\(Int(round(percent * 100)))%")
                        }
                        .gaugeStyle(AccessoryCircularGaugeStyle())
                        .widgetURL(URL(string: "dimeapp://budget?budget=\(entry.budget.name)"))
                    } else {
                        EmptyView()
                    }
                }
            }

        case .accessoryRectangular:
            if #available(iOS 17.0, *) {
                if entry.configuration.budget == nil {
                    Text("SELECT BUDGET IN WIDGET OPTIONS")
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
                                    Text("•")
                                    Text(percentString)
                                }
                            }
                            .font(.system(size: 15, weight: .semibold, design: .rounded))

                            Text("\(currencySymbol)\(difference, specifier: (showCents && difference < 100) ? "%.2f" : "%.0f") \(subtitle) \(budgetType)")
                                .font(.system(size: 14, weight: .regular, design: .rounded))
                                .foregroundColor(Color.SubtitleText)

                            Gauge(value: percent, in: 0 ... 1) {
                                Text("Percent Spent")
                            } currentValueLabel: {
                                EmptyView()
                            } minimumValueLabel: {
                                Text("\(entry.totalSpent, specifier: (showCents && entry.totalSpent < 100) ? "%.2f" : "%.0f")")
                                    .font(.system(size: 10, weight: .regular, design: .rounded))
                            } maximumValueLabel: {
                                Text("\(entry.budget.budgetAmount, specifier: (showCents && entry.budget.budgetAmount < 100) ? "%.2f" : "%.0f")")
                                    .font(.system(size: 10, weight: .regular, design: .rounded))
                            }
                            .frame(height: 5)
                            .gaugeStyle(.accessoryLinear)
                        }
                        .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .widgetURL(URL(string: "dimeapp://budget?budget=\(entry.budget.name)"))
                    .containerBackground(for: .widget) { Color.clear }
                }
            } else {
                if entry.configuration.budget == nil {
                    Text("SELECT BUDGET IN WIDGET OPTIONS")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                } else {
                    GeometryReader { proxy in
                        VStack(alignment: .leading) {
                            HStack(spacing: 3) {
                                Text(entry.budget.name)

                                if showPercent(size: proxy.size.width) {
                                    Text("•")
                                    Text(percentString)
                                }
                            }
                            .font(.system(size: 15, weight: .semibold, design: .rounded))

                            Text("\(currencySymbol)\(difference, specifier: (showCents && difference < 100) ? "%.2f" : "%.0f") \(subtitle) \(budgetType)")
                                .font(.system(size: 14, weight: .regular, design: .rounded))
                                .foregroundColor(Color.SubtitleText)

                            if #available(iOS 16.0, *) {
                                Gauge(value: percent, in: 0 ... 1) {
                                    Text("Percent Spent")
                                } currentValueLabel: {
                                    EmptyView()
                                } minimumValueLabel: {
                                    Text("\(entry.totalSpent, specifier: (showCents && entry.totalSpent < 100) ? "%.2f" : "%.0f")")
                                        .font(.system(size: 10, weight: .regular, design: .rounded))
                                } maximumValueLabel: {
                                    Text("\(entry.budget.budgetAmount, specifier: (showCents && entry.budget.budgetAmount < 100) ? "%.2f" : "%.0f")")
                                        .font(.system(size: 10, weight: .regular, design: .rounded))
                                }
                                .frame(height: 5)
                                .gaugeStyle(.accessoryLinear)
                            }
                        }
                        .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .widgetURL(URL(string: "dimeapp://budget?budget=\(entry.budget.name)"))
                }
            }

        default:
            EmptyView()
        }
    }

    func showPercent(size: CGFloat) -> Bool {
        return size > entry.budget.name.widthOfRoundedString(size: 15, weight: .semibold) + 15 + percentString.widthOfRoundedString(size: 15, weight: .semibold)
    }
}
