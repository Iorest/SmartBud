//
//  InsightsWidgetViews.swift
//  smartbud
//
import Foundation
import SwiftUI
import WidgetKit
import SwiftData

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
            return String.appFormatted("in %@", formatter.string(from: Date.now)).uppercased()
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

    /// The average label would collide with the bars at the extremes.
    var averageLabelOpacity: Double {
        let ratio = entry.average / Double(getMax())
        return ratio < 0.2 || ratio > 0.8 ? 0 : 1
    }

    /// Height of one bar, reading the bucket total straight from the entry.
    func barHeight(for day: Date, in size: CGSize) -> CGFloat {
        getBarHeight(point: entry.dictionary[day] ?? 0, size: size)
    }

    /// 1-based position of a bucket, used for the day / month tick labels.
    func dayNumber(for day: Date) -> Int {
        (entry.dates.firstIndex(of: day) ?? -1) + 1
    }

    /// Short month name for the quarter markers ("Jan", "4月", …).
    func monthName(for day: Date) -> String {
        monthNames[dayNumber(for: day)] ?? ""
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
