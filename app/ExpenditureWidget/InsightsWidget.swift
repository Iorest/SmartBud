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
        AppIntentConfiguration(kind: kind, intent: InsightsWidgetConfigurationIntent.self, provider: InsightsProvider()) { entry in
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
            $0.income == income && $0.wrappedDate >= period.startDate && $0.wrappedDate <= now
        }
        let allCategories = (try? context.fetch(FetchDescriptor<CategoryModel>())) ?? []
        let categories = allCategories.filter { $0.income == income }

        let series = bucketSeries(for: transactions, period: period, calendar: calendar)
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
                                          total: series.total)
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
            let start = getStartOfMonth(startDay: startDay)
            guard let range = calendar.range(of: .day, in: .month, for: start) else { return nil }
            return PeriodSpec(startDate: start, step: .day, value: 1,
                              count: range.count, elapsedUnit: .day)
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
                              calendar: Calendar) -> BucketSeries {
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
                .reduce(0.0) { $0 + $1.wrappedAmount }

            total += bucket
            byDate[cursor] = bucket
            maximum = max(maximum, bucket)
            if bucket != 0 { activeDays += 1 }
            dates.append(cursor)
            cursor = next
        }

        return BucketSeries(total: total, maximum: maximum, activeDays: activeDays,
                            dates: dates, byDate: byDate)
    }

    private func categoryBreakdown(transactions: [TransactionModel],
                                   categories: [CategoryModel],
                                   total: Double) -> [HoldingCategory] {
        guard total > 0 else { return [] }
        return categories.compactMap { category in
            let amount = transactions
                .filter { $0.category == category }
                .reduce(0.0) { $0 + $1.wrappedAmount }
            guard amount != 0 else { return nil }
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

struct InsightsWidgetEntryView: View {
    let entry: InsightsProvider.Entry

    let numberArray = [1, 8, 15, 22, 29]
    let monthNumberArray = [1, 4, 7, 10]

    /// Short month names for the four quarter markers (Jan/Apr/Jul/Oct in
    /// English; "1月"/"4月"/"7月"/"10月" in zh-Hans, etc.). Built on every
    /// body evaluation so it stays in sync with Locale.appLocale.
    var monthNames: [Int: String] {
        let formatter = DateFormatter()
        formatter.locale = Locale.appLocale
        formatter.dateFormat = "MMM"
        let calendar = Calendar(identifier: .gregorian)
        return monthNumberArray.reduce(into: [:]) { dict, month in
            var components = DateComponents()
            components.year = 2024
            components.month = month
            components.day = 1
            if let date = calendar.date(from: components) {
                dict[month] = formatter.string(from: date)
            }
        }
    }

    @AppStorage("firstDayOfMonth", store: .appGroup) var firstDayOfMonth: Int = 1
    @AppStorage("currency", store: .appGroup) var currency: String = Locale.current.currency?.identifier ?? "USD"
    var currencySymbol: String {
        return Locale.appCurrencySymbol(forCurrencyCode: currency)
    }

    @AppStorage("showCents", store: .appGroup) var showCents: Bool = true

    var dollarText: String {
        if entry.amount < 10000 && showCents {
            return entry.amount.formatted(.number.precision(.fractionLength(2)))
        } else {
            return Int(round(entry.amount)).formatted(.number)
        }
    }

    var subtitleText: String {
        switch entry.duration {
        case .unknown:
            return String.appLocalized("NIL")
        case .week:
            return String.appLocalized("THIS WEEK").uppercased()
        case .month:
            return String.appLocalized("THIS MONTH").uppercased()
        case .year:
            let formatter = DateFormatter()
            formatter.locale = Locale.appLocale
            formatter.dateFormat = "yyyy"
            return String(localized: "in \\(formatter.string(from: Date.now))").uppercased()
        }
    }

    var subtitleText1: String {
        switch entry.duration {
        case .unknown:
            return String.appLocalized("NIL")
        case .week:
            return String.appLocalized("THIS WEEK").uppercased()
        case .month:
            return String.appLocalized("THIS MONTH").uppercased()
        case .year:
            return String.appLocalized("THIS YEAR").uppercased()
        }
    }

    var verbText: String {
        if entry.income {
            return String.appLocalized("EARNED ").uppercased()
        } else {
            return String.appLocalized("SPENT ").uppercased()
        }
    }

    var body: some View {
        GeometryReader { proxy in
            HStack(spacing: 0) {
                VStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: -1) {
                        Text("\(verbText)\(subtitleText)")
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundColor(Color.SubtitleText)

                        InsightsWidgetDollarView(currencySymbol: currencySymbol, dollarText: dollarText)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    GeometryReader { proxy in
                        ZStack(alignment: .top) {
                            HStack(alignment: .top, spacing: 4) {
                                // axes
                                VStack(alignment: .leading) {
                                    Text(getMaxText())
                                        .lineLimit(1)
                                        .font(.system(size: 8, weight: .regular, design: .rounded))
                                        .foregroundColor(Color.SubtitleText)

                                    Spacer()

                                    Text(String.appLocalized("0"))
                                        .font(.system(size: 8, weight: .regular, design: .rounded))
                                        .foregroundColor(Color.SubtitleText)
                                }
                                .frame(height: proxy.size.height * 0.85)

                                if entry.duration == .week {
                                    HStack(spacing: 3) {
                                        ForEach(entry.dates, id: \.self) { day in
                                            VStack(spacing: 3) {
                                                ZStack(alignment: .bottom) {
                                                    RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                                                        .fill(Color.SecondaryBackground)
                                                        .frame(height: proxy.size.height * 0.85)

                                                    RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                                                        .frame(height: getBarHeight(point: entry.dictionary[day] ?? 0, size: proxy.size))
                                                }

                                                Text(getWeekday(day: day).prefix(1))
                                                    .font(.system(size: 8, weight: .bold, design: .rounded))
                                                    .foregroundColor(Color.SubtitleText)
                                            }
                                            .opacity(day > Date.now ? 0.3 : 1)
                                            .frame(maxWidth: .infinity)
                                        }
                                    }
                                    .frame(maxWidth: .infinity)
                                } else if entry.duration == .month {
                                    HStack(spacing: 1.5) {
                                        ForEach(entry.dates, id: \.self) { day in
                                            ZStack(alignment: .bottom) {
                                                Capsule()
                                                    .fill(Color.SecondaryBackground)
                                                    .frame(height: proxy.size.height * 0.85)

                                                Capsule()
                                                    .frame(height: getBarHeight(point: entry.dictionary[day] ?? 0, size: proxy.size))
                                                    .overlay(alignment: .bottom) {
                                                        if numberArray.contains((entry.dates.firstIndex(of: day) ?? -1) + 1) && firstDayOfMonth == 1 {
                                                            Text("\((entry.dates.firstIndex(of: day) ?? -1) + 1)")
                                                                .font(.system(size: 8, weight: .bold, design: .rounded))
                                                                .foregroundColor(Color.SubtitleText)
                                                                .frame(width: 20, alignment: .center)
                                                                .offset(y: 15)
                                                        }
                                                    }
                                            }
                                            .padding(.bottom, firstDayOfMonth == 1 ? 13 : 0)
                                            .opacity(day > Date.now ? 0.3 : 1)
                                            .frame(maxWidth: .infinity)
                                        }
                                    }
                                    .frame(maxWidth: .infinity)
                                } else {
                                    HStack(spacing: 2.5) {
                                        ForEach(entry.dates, id: \.self) { day in
                                            ZStack(alignment: .bottom) {
                                                RoundedRectangle(cornerRadius: 2.7, style: .continuous)
                                                    .fill(Color.SecondaryBackground)
                                                    .frame(height: proxy.size.height * 0.85)

                                                RoundedRectangle(cornerRadius: 2.7, style: .continuous)
                                                    .frame(height: getBarHeight(point: entry.dictionary[day] ?? 0, size: proxy.size))
                                                    .overlay(alignment: .bottom) {
                                                        if monthNumberArray.contains((entry.dates.firstIndex(of: day) ?? -1) + 1) {
                                                            Text(LocalizedStringKey(monthNames[(entry.dates.firstIndex(of: day)! + 1)] ?? ""))
                                                                .font(.system(size: 8, weight: .bold, design: .rounded))
                                                                .foregroundColor(Color.SubtitleText)
                                                                .frame(width: 20, alignment: .center)
                                                                .offset(y: 15)
                                                        }
                                                    }
                                            }
                                            .padding(.bottom, 13)
                                            .opacity(day > Date.now ? 0.3 : 1)
                                            .frame(maxWidth: .infinity)
                                        }
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                            }
                            .frame(width: proxy.size.width)
                            .frame(maxHeight: .infinity)

                            HStack(spacing: 4) {
                                Text(getAverageText())
                                    .lineLimit(1)
                                    .font(.system(size: 8, weight: .regular, design: .rounded))
                                    .foregroundColor(Color.PrimaryText)
                                    .opacity((entry.average / Double(getMax())) < 0.2 || (entry.average / Double(getMax())) > 0.8 ? 0 : 1)

                                Line()
                                    .stroke(Color.SubtitleText, style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [5]))
                                    .frame(height: 1)
                                    .frame(maxWidth: .infinity)
                            }
                            .frame(width: proxy.size.width)
                            .opacity(entry.numberOfDays <= 1 ? 0 : 1)
                            .offset(y: getOffset(size: proxy.size) - 5)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .padding([.trailing], 20)
                .frame(width: 185)
                .frame(maxHeight: .infinity)
                .background(WidgetGlassBackground())

                InsightsWidgetCategoryBreakdownView(amount: entry.amount, income: entry.income, categories: entry.categories, duration: entry.duration, ios17: true)
//                    .frame(width: proxy.size.width * 0.43)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .widgetURL(URL(string: "smartbud://insights"))
        .containerBackground(for: .widget) {
            WidgetGlassBackground()
        }
    }

    func getOffset(size: CGSize) -> Double {
        let maxi = getMax()

        if maxi == 0 {
            return 0
        } else {
            let height = (size.height * 0.85) - ((entry.average / Double(maxi)) * (size.height * 0.85))
            return height
        }
    }

    func getAverageText() -> String {
        let string = String(entry.average)

        let stringArray = string.compactMap { String($0) }

        if entry.average >= 1_000_000 {
            return stringArray[0] + "M"
        } else if entry.average >= 100_000 {
            return string.prefix(3) + "k"
        } else if entry.average >= 10000 {
            return string.prefix(2) + "k"
        } else if entry.average >= 1000 {
            return stringArray[0] + "." + stringArray[1] + "k"
        } else {
            return String(Int(round(entry.average)))
        }
    }

    func getMaxText() -> String {
        let maxi = getMax()

        if maxi == 0 {
            return "10"
        }

        let string = String(maxi)

        let stringArray = string.compactMap { String($0) }

        if maxi >= 1_000_000 {
            return stringArray[0] + "M"
        } else if maxi >= 100_000 {
            return string.prefix(3) + "k"
        } else if maxi >= 10000 {
            return string.prefix(2) + "k"
        } else if maxi >= 1000 {
            let string = String(maxi)

            let stringArray = string.compactMap { String($0) }

            return stringArray[0] + "." + stringArray[1] + "k"
        } else {
            return String(maxi)
        }
    }

    func getMax() -> Int {
        let maximum = entry.maximum * 1.1

        return Int(ceil(maximum / 10) * 10)
    }

    func getBarHeight(point: CGFloat, size: CGSize) -> CGFloat {
        let maxi = getMax()

        if maxi == 0 {
            return 0
        } else {
            let height = (point / CGFloat(maxi)) * (size.height * 0.85)
            return height
        }
    }

    func getWeekday(day: Date) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale.appLocale

        dateFormatter.dateFormat = "EEE"

        return dateFormatter.string(from: day)
    }
}

struct HoldingCategory: Hashable {
    let colour: String
    let name: String
    let percent: Double
}

struct HorizontalBarGraph: View {
    var categories: [HoldingCategory]
    let income: Bool

    var body: some View {
        GeometryReader { proxy in
            HStack(spacing: proxy.size.width * 0.015) {
                ForEach(categories, id: \.self) { category in
                    if category.percent < 0.02 {
                        EmptyView()
                    } else if category.percent < 0.1 {
                        RoundedRectangle(cornerRadius: 0.09 + (0.25 * category.percent * 100), style: .continuous)
                            .fill(income ? Color(hex: Color.colorArray[categories.firstIndex(of: category) ?? 0]) : Color(hex: category.colour))
                            .frame(width: (proxy.size.width * (1.0 - (0.015 * Double(categories.count - 1)))) * category.percent)

                    } else {
                        RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                            .fill(income ? Color(hex: Color.colorArray[categories.firstIndex(of: category) ?? 0]) : Color(hex: category.colour))
                            .frame(width: (proxy.size.width * (1.0 - (0.015 * Double(categories.count - 1)))) * category.percent)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct InsightsWidgetDollarView: View {
    let currencySymbol: String
    let dollarText: String

    var body: some View {
        HStack(alignment: .lastTextBaseline, spacing: 1.3) {
            Text(currencySymbol)
                .font(.system(.subheadline, design: .rounded).weight(.medium))
                .foregroundColor(Color.SubtitleText)

            Text(dollarText)
                .font(.system(.title3, design: .rounded).weight(.medium))
                .foregroundColor(Color.PrimaryText)
        }
        .minimumScaleFactor(0.5)
        .lineLimit(1)
    }
}

struct InsightsWidgetCategoryBreakdownView: View {
    let amount: Double
    let income: Bool
    let categories: [HoldingCategory]
    let duration: InsightsTimePeriod
    let ios17: Bool

    var subtitleText1: String {
        switch duration {
        case .unknown:
            return String.appLocalized("NIL")
        case .week:
            return String.appLocalized("THIS WEEK").uppercased()
        case .month:
            return String.appLocalized("THIS MONTH").uppercased()
        case .year:
            return String.appLocalized("THIS YEAR").uppercased()
        }
    }

    var body: some View {
        VStack(spacing: 8) {
            if amount != 0 {
                HorizontalBarGraph(categories: categories, income: income)
                    .frame(height: 16)

                VStack(spacing: 5) {
                    ForEach(Array(categories.prefix(3)), id: \.self) { category in
                        HStack(spacing: 7) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(income ? Color(hex: Color.colorArray[categories.firstIndex(of: category) ?? 0]) : Color(hex: category.colour))
                                .frame(width: 8, height: 8)
                            Text(category.name)
                                .lineLimit(1)
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundColor(Color.PrimaryText)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            Text("\(Int(round(category.percent * 100)))%")
                                .font(.system(size: 12, weight: .regular, design: .rounded))
                                .foregroundColor(Color.SubtitleText)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            } else {
                Text(String.appFormatted("NO TRANSACTIONS\n%@", subtitleText1))
                    .font(.system(size: 10,
                                  weight: .medium, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundColor(Color.SubtitleText)
                    .frame(maxHeight: .infinity)
            }

            Link(destination: URL(string: "smartbud://newExpense")!) {
                HStack(spacing: 4) {
                    Image(systemName: "plus")
                        .font(.system(size: 9, weight: .medium, design: .rounded))

                    Text(String.appLocalized("New Expense"))
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(Color.PrimaryText)
                }
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity)
                .background(RoundedRectangle(cornerRadius: SBRadius.chip).fill(ios17 ? Color.SecondaryBackground : Color.PrimaryBackground))
            }
        }
    }
}
