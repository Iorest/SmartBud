//
//  LogSteppers+Month.swift
//  smartbud
//
import Foundation
import SwiftData
import SwiftUI

struct MonthStepperView: View {
    @Query(sort: [SortDescriptor(\TransactionModel.day)]) private var transactions: [TransactionModel]

    @Query private var transactionsReversed: [TransactionModel]

    @Binding var showingDate: Date
    var endDate: Date {
        if transactions.isEmpty {
            return Date.now
        } else {
            let calendar = Calendar(identifier: .gregorian)

            let date = transactions[0].day ?? Date.now

            let dateComponents = calendar.dateComponents([.month, .year], from: date)

            return calendar.date(from: dateComponents) ?? Date.now
        }
    }

    @State var startDate = Date.now

    var dateString: String {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale.appLocale

        dateFormatter.dateFormat = "MMM yyyy"

        return dateFormatter.string(from: showingDate)
    }

    var body: some View {
        HStack {
            StepperButtonView(left: true, disabled: showingDate == endDate) {
                if showingDate > endDate {
                    showingDate = Calendar.current.date(byAdding: .month, value: -1, to: showingDate) ?? Date.now
                }
            }
            .accessibilityLabel(Text(String.appLocalized("previous month")))

            Spacer()

            Text(dateString)
                .font(.headline)
                .accessibilityLabel(String.appFormatted("showing transactions in %@", dateString))

            Spacer()

            StepperButtonView(left: false, disabled: showingDate == startDate) {
                if showingDate < startDate {
                    showingDate = Calendar.current.date(byAdding: .month, value: 1, to: showingDate) ?? Date.now
                }
            }
            .accessibilityLabel(Text(String.appLocalized("next month")))
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            let calendar = Calendar(identifier: .gregorian)

            let date = transactionsReversed[0].day ?? Date.now

            let dateComponents = calendar.dateComponents([.month, .year], from: date)

            startDate = calendar.date(from: dateComponents) ?? Date.now

            showingDate = startDate
        }
    }

    init(showingDate: Binding<Date>) {
        self._showingDate = showingDate
        let now = Date.now
        let future = Date.distantFuture
        _transactionsReversed = Query(
            filter: #Predicate<TransactionModel> { ($0.date ?? future) < now },
            sort: [SortDescriptor(\TransactionModel.day, order: .reverse)]
        )
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
