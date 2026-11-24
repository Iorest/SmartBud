//
//  NewExpenseWidget.swift
//  ExpenditureWidgetExtension
//
//  Created by Iorest on 9/9/22.
//

import SwiftUI
import WidgetKit

struct NewExpenseWidget: Widget {
    let kind: String = "AddExpense"

    private let supportedFamilies: [WidgetFamily] = [.accessoryCircular]

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NewExpenseProvider()) { entry in
            NewExpenseWidgetEntryView(entry: entry)
                .environment(\.locale, Locale.appLocale)
        }
        .configurationDisplayName("New Expense")
        .description("A convenient button to log new purchases.")
        .supportedFamilies(supportedFamilies)
    }
}

struct NewExpenseProvider: TimelineProvider {
    typealias Entry = NewExpenseWidgetEntry

    func placeholder(in _: Context) -> NewExpenseWidgetEntry {
        NewExpenseWidgetEntry(date: .now)
    }

    func getSnapshot(in _: Context, completion: @escaping (NewExpenseWidgetEntry) -> Void) {
        let entry = NewExpenseWidgetEntry(date: .now)
        completion(entry)
    }

    func getTimeline(in _: Context, completion: @escaping (Timeline<NewExpenseWidgetEntry>) -> Void) {
        let entry = NewExpenseWidgetEntry(date: .now)

        let timeline = Timeline(entries: [entry], policy: .atEnd)

        completion(timeline)
    }
}

struct NewExpenseWidgetEntry: TimelineEntry {
    let date: Date
}

struct NewExpenseWidgetEntryView: View {
    let entry: NewExpenseProvider.Entry

    @AppStorage("currency", store: .appGroup) var currency: String = Locale.current.currency?.identifier ?? "USD"
    var currencySymbol: String {
        return Locale.appCurrencySymbol(forCurrencyCode: currency)
    }

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()

            Text("\(currencySymbol.count < 3 ? "+" : "")\(currencySymbol)")
                .font(.system(size: currencySymbol.count < 3 ? 13 : 11, weight: .bold, design: .rounded))
                .foregroundStyle(Color.SecondaryBackground)
                .padding(.vertical, 2)
                .frame(maxWidth: .infinity)
                .background(Color.white, in: RoundedRectangle(cornerRadius: SBRadius.pill, style: .continuous))
                .padding(.horizontal, 9)
        }
        .widgetURL(widgetDeepLink("newExpense"))
        .containerBackground(for: .widget) {
            AccessoryWidgetBackground()
        }
    }
}
