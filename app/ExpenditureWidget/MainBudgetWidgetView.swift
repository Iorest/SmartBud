//
//  MainBudgetWidgetView.swift
//  smartbud
//
import SwiftUI
import WidgetKit
import SwiftData

struct MainBudgetWidgetEntryView: View {
    @Environment(\.widgetFamily) var widgetFamily
    let entry: MainBudgetWidgetProvider.Entry

    var budgetType: String {
        switch entry.type {
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

    var headingText: String {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale.appLocale

        switch entry.type {
        case 1:
            dateFormatter.dateFormat = "d MMM yyyy"
            return dateFormatter.string(from: entry.startDate)
        case 2:
            dateFormatter.dateFormat = "d MMM"
            let endComponents = DateComponents(day: 7, second: -1)
            guard let endWeekDate = Calendar.current.date(byAdding: endComponents, to: entry.startDate) else {
                return formatDateRange(date1: entry.startDate, date2: entry.startDate)
            }
            return formatDateRange(date1: entry.startDate, date2: endWeekDate)
//            return dateFormatter.string(from: entry.startDate) + " - " + dateFormatter.string(from: endWeekDate)
        case 3:
            dateFormatter.dateFormat = "d MMM"
            let endComponents = DateComponents(month: 1, second: -1)
            guard let endWeekDate = Calendar.current.date(byAdding: endComponents, to: entry.startDate) else {
                return formatDateRange(date1: entry.startDate, date2: entry.startDate)
            }
            return formatDateRange(date1: entry.startDate, date2: endWeekDate)
//            return dateFormatter.string(from: entry.startDate) + " - " + dateFormatter.string(from: endWeekDate)
        case 4:
            dateFormatter.dateFormat = "d MMM yy"
            return dateFormatter.string(from: entry.startDate)
        default:
            return ""
        }
    }

    var difference: Double {
        return abs(entry.budgetAmount - entry.totalSpent)
    }

    var percentString: String {
        return String(localized: "\(Int(round((entry.totalSpent / entry.budgetAmount) * 100)))% spent")
    }

    var percentString1: String {
        return "\(Int(round((entry.totalSpent / entry.budgetAmount) * 100)))%"
    }

    var percent: Double {
        return entry.totalSpent / entry.budgetAmount
    }

    var systemSmallWidgetText: String {
        if entry.budgetAmount >= entry.totalSpent {
            return String(localized: "left \(budgetType)")
        } else {
            return String(localized: "over \(budgetType)")
        }
    }

    func showPercent(size: CGFloat) -> Bool {
        return size > headingText
            .widthOfRoundedString(size: 15, weight: .semibold) + 15 + percentString
            .widthOfRoundedString(size: 15, weight: .semibold)
    }

    func showTimeFrame(size: CGFloat) -> Bool {
        return size > systemSmallWidgetText.widthOfRoundedString(size: 10, weight: .semibold)
    }

    @AppStorage("currency", store: .appGroup) var currency: String = Locale.current.currency?.identifier ?? "USD"
    var currencySymbol: String {
        return Locale.appCurrencySymbol(forCurrencyCode: currency)
    }

    @AppStorage("showCents", store: .appGroup) var showCents: Bool = true

    var body: some View {
        switch widgetFamily {
        case .accessoryCircular:
            if !entry.found {
                ZStack {
                    AccessoryWidgetBackground()

                    VStack {
                        Text(String.appLocalized("ADD BUDGET"))
                            .font(.system(size: 8, weight: .semibold, design: .rounded))
                            .frame(maxWidth: .infinity)
                            .multilineTextAlignment(.center)
                    }
                }
                .containerBackground(for: .widget) { AccessoryWidgetBackground() }
            } else {
                Gauge(value: percent < 1 ? percent : 1) {
                    Image(systemName: "dollarsign.circle.fill")
                } currentValueLabel: {
                    Text("\(Int(round(percent * 100)))%")
                }
                .gaugeStyle(AccessoryCircularGaugeStyle())
                .containerBackground(for: .widget) { Color.clear }
            }

        case .accessoryRectangular:
            if !entry.found {
                Text(String.appLocalized("ADD OVERALL BUDGET"))
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .containerBackground(for: .widget) { Color.clear }
            } else {
                GeometryReader { proxy in
                    VStack(alignment: .leading) {
                        HStack(spacing: 3) {
                            Text(headingText)

                            if showPercent(size: proxy.size.width) {
                                Text(String.appLocalized("•"))
                                Text(percentString)
                            }
                        }
                        .font(.system(size: 15, weight: .semibold, design: .rounded))

                        let statusText = entry.totalSpent > entry.budgetAmount
                            ? String.appLocalized("over")
                            : String.appLocalized("left")
                        let amount = amountText(difference, showCents: showCents)
                        Text("\(currencySymbol)\(amount) \(statusText) \(budgetType)")
                            .font(.system(size: 14, weight: .regular, design: .rounded))
                            .foregroundColor(Color.SubtitleText)

                        Gauge(value: percent, in: 0 ... 1) {
                            Text(String.appLocalized("Percent Spent"))
                        } currentValueLabel: {
                            EmptyView()
                        } minimumValueLabel: {
                            Text(amountText(entry.totalSpent, showCents: showCents))
                                .font(.system(size: 10, weight: .regular, design: .rounded))
                        } maximumValueLabel: {
                            Text(amountText(entry.budgetAmount, showCents: showCents))
                                .font(.system(size: 10, weight: .regular, design: .rounded))
                        }
                        .frame(height: 5)
                        .gaugeStyle(.accessoryLinear)
                    }
                    .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .containerBackground(for: .widget) { Color.clear }
            }

        case .systemSmall:
            if !entry.found {
                Text(String.appLocalized("Create your overall budget in the app"))
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundColor(Color.SubtitleText)
                    .padding(15)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .containerBackground(for: .widget) { WidgetGlassBackground() }
            } else {
                VStack(spacing: 12) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 2.4) {
                            Text(headingText.uppercased())
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .lineLimit(1)
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

                                    if entry.totalSpent / entry.budgetAmount < 0.97 {
                                        DonutSemicircle(
                                            percent: 1 - (entry.totalSpent / entry.budgetAmount),
                                            cornerRadius: 4,
                                            width: 15
                                        )
                                            .fill(Color.DarkBackground)
                                            .frame(width: proxy.size.width, height: proxy.size.width / 2)
                                    }
                                }
                                .frame(width: proxy.size.width)

                                VStack(spacing: -4) {
                                    WidgetBudgetDollarView(
                                        amount: difference,
                                        red: entry.totalSpent >= entry.budgetAmount
                                    )
                                        .frame(width: proxy.size.width - 50)

                                    if showTimeFrame(size: proxy.size.width - 50) {
                                        Text(systemSmallWidgetText)
                                            .font(.system(size: 10, weight: .medium, design: .rounded))
                                            .foregroundColor(Color.SubtitleText)
                                    } else {
                                        if entry.budgetAmount >= entry.totalSpent {
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
                                if entry.totalSpent > 999.99 || entry.budgetAmount > 999.99 {
                                    Text("\(Int(round(entry.totalSpent)))")
                                        .frame(width: 50, alignment: .leading)
                                    Spacer()
                                    Text("\(Int(round(entry.budgetAmount)))")
                                        .frame(width: 50, alignment: .trailing)
                                } else {
                                    Text("\(entry.totalSpent, specifier: "%.2f")")
                                        .frame(width: 50, alignment: .leading)
                                    Spacer()
                                    Text("\(entry.budgetAmount, specifier: "%.2f")")
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
                .containerBackground(for: .widget) { WidgetGlassBackground() }
            }

        default:
            EmptyView()
        }
    }
}

func formatDateRange(date1: Date, date2: Date) -> String {
    let dateFormatter = DateFormatter()
    dateFormatter.locale = Locale.appLocale

    let calendar = Calendar.current
    let components1 = calendar.dateComponents([.day, .month], from: date1)
    let components2 = calendar.dateComponents([.day, .month], from: date2)

    if components1.month == components2.month {
        dateFormatter.dateFormat = "MMM"
        let dateString = dateFormatter.string(from: date1)
        return "\(components1.day!) - \(components2.day!) \(dateString)"
    } else {
        dateFormatter.dateFormat = "d MMM"
        let startDateString = dateFormatter.string(from: date1)
        let endDateString = dateFormatter.string(from: date2)
        return "\(startDateString) - \(endDateString)"
    }
}
