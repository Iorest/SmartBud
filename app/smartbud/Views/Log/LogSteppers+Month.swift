//
//  LogSteppers+Month.swift
//  smartbud
//
import Foundation
import SwiftData
import SwiftUI

struct MonthStepperView: View {
    @Query(sort: [SortDescriptor(\TransactionModel.day)]) private var transactions: [TransactionModel]

    @Binding var showingDate: Date

    /// Month buckets honour Settings → Time Frames → Start of Month, exactly
    /// like Insights and the widgets do.
    private var calendar: Calendar {
        AppPeriod.configuredCalendar(
            firstWeekday: UserDefaults.appGroup.integer(forKey: "firstWeekday"))
    }

    private var startDay: Int {
        UserDefaults.appGroup.integer(forKey: "firstDayOfMonth")
    }

    private var currentStart: Date {
        AppPeriod.monthStart(containing: .now, startDay: startDay, calendar: calendar)
    }

    private var oldestStart: Date? {
        guard let oldest = transactions.first?.day else { return nil }
        return AppPeriod.monthStart(containing: oldest, startDay: startDay, calendar: calendar)
    }

    private var canGoBack: Bool { showingDate > (oldestStart ?? currentStart) }
    private var canGoForward: Bool { showingDate < currentStart }

    /// "2026年10月" / "October 2026" — `MMM yyyy` produced "10月 2026" in
    /// Chinese, which reads as a month that happens to be followed by a number.
    private var dateString: String {
        showingDate.formatted(
            Date.FormatStyle(locale: .appLocale).year().month(.wide))
    }

    var body: some View {
        HStack {
            StepperButtonView(left: true, disabled: !canGoBack) {
                showingDate = calendar.date(byAdding: .month, value: -1, to: showingDate)
                    ?? showingDate
            }
            .accessibilityLabel(Text(String.appLocalized("previous month")))

            Spacer()

            Text(dateString)
                .font(.headline)
                .accessibilityLabel(String.appFormatted("showing transactions in %@", dateString))

            Spacer()

            StepperButtonView(left: false, disabled: !canGoForward) {
                showingDate = calendar.date(byAdding: .month, value: 1, to: showingDate)
                    ?? showingDate
            }
            .accessibilityLabel(Text(String.appLocalized("next month")))
        }
        .frame(maxWidth: .infinity)
        .onAppear { showingDate = currentStart }
    }

    init(showingDate: Binding<Date>) {
        self._showingDate = showingDate
    }
}

func dateConverter(date: Date) -> String {
    let calendar = Calendar.current

    let dateComponents = calendar.dateComponents([.year], from: Date.now)

    let startOfCurrentYear = calendar.date(from: dateComponents) ?? Date.now

    if calendar.isDateInToday(date) {
        return String.appLocalized("today")
    } else if calendar.isDateInYesterday(date) {
        return String.appLocalized("yesterday")
    } else if startOfCurrentYear > date {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale.appLocale

        dateFormatter.dateFormat = "EEE, d MMM yy"

        var string = dateFormatter.string(from: date)
        string.insert("'", at: string.index(string.endIndex, offsetBy: -2))

        return string
    } else {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale.appLocale

        dateFormatter.dateFormat = "EEE, d MMM"

        return dateFormatter.string(from: date)
    }
}

func dateConverterAccessibilityLabel(date: Date) -> String {
    let calendar = Calendar.current

    if calendar.isDateInToday(date) {
        return String.appLocalized("today")
    } else if calendar.isDateInYesterday(date) {
        return String.appLocalized("yesterday")
    } else {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale.appLocale

        dateFormatter.dateFormat = "EEE, d MMM yyyy"

        return String.appFormatted("on %@", dateFormatter.string(from: date))
    }
}

func timeConverterAccessibilityLabel(date: Date) -> String {
    let dateFormatter = DateFormatter()
    dateFormatter.locale = Locale.appLocale

    dateFormatter.dateFormat = "h:mm a"

    return dateFormatter.string(from: date)
}
