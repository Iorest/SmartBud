//
//  InsightsWidgetCharts.swift
//  smartbud
//
import Foundation
import SwiftUI
import WidgetKit
import SwiftData

struct HorizontalBarGraph: View {
    var categories: [HoldingCategory]
    let income: Bool

    func color(for category: HoldingCategory) -> Color {
        widgetCategoryColor(category, among: categories, income: income)
    }

    /// Bar width, leaving a 1.5% gap between segments.
    func width(for category: HoldingCategory, total: CGFloat) -> CGFloat {
        let gaps = 0.015 * Double(categories.count - 1)
        return total * (1.0 - gaps) * category.percent
    }

    var body: some View {
        GeometryReader { proxy in
            HStack(spacing: proxy.size.width * 0.015) {
                ForEach(categories, id: \.self) { category in
                    if category.percent < 0.02 {
                        EmptyView()
                    } else if category.percent < 0.1 {
                        RoundedRectangle(cornerRadius: 0.09 + (0.25 * category.percent * 100),
                                         style: .continuous)
                            .fill(color(for: category))
                            .frame(width: width(for: category, total: proxy.size.width))

                    } else {
                        RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                            .fill(color(for: category))
                            .frame(width: width(for: category, total: proxy.size.width))
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
                                .fill(widgetCategoryColor(category, among: categories, income: income))
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
                .background(RoundedRectangle(cornerRadius: SBRadius.chip)
                    .fill(ios17 ? Color.SecondaryBackground : Color.PrimaryBackground))
            }
        }
    }
}

extension InsightsWidgetEntryView {

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
                                                        .frame(height: barHeight(for: day, in: proxy.size))
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
                                                    .frame(height: barHeight(for: day, in: proxy.size))
                                                    .overlay(alignment: .bottom) {
                                                        if numberArray.contains(dayNumber(for: day))
                                                            && firstDayOfMonth == 1 {
                                                            Text("\(dayNumber(for: day))")
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
                                                    .frame(height: barHeight(for: day, in: proxy.size))
                                                    .overlay(alignment: .bottom) {
                                                        if monthNumberArray.contains(dayNumber(for: day)) {
                                                            Text(LocalizedStringKey(monthName(for: day)))
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
                                    .opacity(averageLabelOpacity)

                                Line()
                                    .stroke(
                                        Color.SubtitleText,
                                        style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [5])
                                    )
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

                InsightsWidgetCategoryBreakdownView(
                    amount: entry.amount,
                    income: entry.income,
                    categories: entry.categories,
                    duration: entry.duration,
                    ios17: true
                )
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
}
