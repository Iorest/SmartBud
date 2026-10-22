//
//  LogTransactionList.swift
//  smartbud
//
//  Native replacement for the hand-rolled log list: one `List`, one section
//  per month, a day header row per day, and real `swipeActions`. The old
//  `SingleTransactionView` drag gesture drew its own delete affordance and
//  relied on screen width; that lives on only inside the budget detail
//  scroll views, where a `List` cannot be nested.
//

import SwiftData
import SwiftUI

// MARK: - Grouping

struct LogDayGroup: Identifiable {
    let day: Date
    let transactions: [TransactionModel]

    var id: Date { day }

    var netTotal: Double {
        transactions.reduce(0) { $0 + ($1.income ? $1.amount : -$1.amount) }
    }
}

struct LogMonthGroup: Identifiable {
    let month: Date
    let days: [LogDayGroup]

    var id: Date { month }
}

enum LogGrouping {
    static func months(_ transactions: [TransactionModel], calendar: Calendar = .current) -> [LogMonthGroup] {
        let byDay = Dictionary(grouping: transactions) { calendar.startOfDay(for: $0.wrappedDate) }

        let days = byDay.map { day, items in
            LogDayGroup(
                day: day,
                transactions: items.sorted { $0.wrappedDate > $1.wrappedDate }
            )
        }
        .sorted { $0.day > $1.day }

        let byMonth = Dictionary(grouping: days) { day in
            calendar.date(from: calendar.dateComponents([.year, .month], from: day.day)) ?? day.day
        }

        return byMonth.map { month, items in
            LogMonthGroup(month: month, days: items.sorted { $0.day > $1.day })
        }
        .sorted { $0.month > $1.month }
    }

    /// "今天"/"昨天"/"10月19日 周一", with the year only when it differs.
    static func dayTitle(_ date: Date, calendar: Calendar = .current) -> String {
        if calendar.isDateInToday(date) {
            return String.appLocalized("today")
        }
        if calendar.isDateInYesterday(date) {
            return String.appLocalized("yesterday")
        }

        let sameYear = calendar.isDate(date, equalTo: .now, toGranularity: .year)
        let formatter = DateFormatter()
        formatter.locale = Locale.appLocale
        formatter.setLocalizedDateFormatFromTemplate(sameYear ? "MMMdEEE" : "yMMMdEEE")
        return formatter.string(from: date)
    }

    static func currency(
        _ amount: Double,
        code: String,
        showCents: Bool,
        signed: Bool,
        income: Bool
    ) -> String {
        Money.format(amount, currencyCode: code, showsCents: showCents,
                     plus: signed ? income : nil)
    }
}

// MARK: - Row

// MARK: - Batch selection bar

/// Bottom action bar shown while multi-selecting log rows.
struct LogSelectionBar: View {
    let count: Int
    let expenseCategories: [CategoryModel]
    let incomeCategories: [CategoryModel]
    let onPick: (CategoryModel) -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: SBSpace.medium) {
            Menu {
                Section(String.appLocalized("Expense")) {
                    ForEach(expenseCategories) { category in
                        categoryButton(category)
                    }
                }
                if !incomeCategories.isEmpty {
                    Section(String.appLocalized("Income")) {
                        ForEach(incomeCategories) { category in
                            categoryButton(category)
                        }
                    }
                }
            } label: {
                Label(String.appLocalized("Move to Category"), systemImage: "folder")
                    .font(.body.weight(.medium))
            }

            Spacer(minLength: 0)

            Button(role: .destructive) {
                onDelete()
            } label: {
                Label(String.appFormatted("Delete (%lld)", count), systemImage: "trash")
                    .font(.body.weight(.medium))
            }
            .foregroundStyle(Color.AlertRed)
        }
        .padding(.horizontal, SBSpace.medium)
        .padding(.vertical, SBSpace.small)
        .frame(maxWidth: .infinity)
        .background(.bar)
        .overlay(alignment: .top) { Divider() }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private func categoryButton(_ category: CategoryModel) -> some View {
        Button("\(category.wrappedEmoji) \(category.wrappedName)") {
            onPick(category)
        }
    }
}

// MARK: - Day header

struct LogDayHeaderRow: View {
    let group: LogDayGroup

    @AppStorage("showCents", store: .appGroup) private var showCents: Bool = true
    @AppStorage("currency", store: .appGroup) private var currency: String = Locale
        .current
        .currency?
        .identifier ?? "USD"

    private var totalText: String {
        LogGrouping.currency(
            group.netTotal,
            code: currency,
            showCents: showCents,
            signed: true,
            income: group.netTotal >= 0
        )
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(LogGrouping.dayTitle(group.day))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.SubtitleText)
            Spacer(minLength: SBSpace.extraSmall)
            Text(totalText)
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(Color.SubtitleText)
                .lineLimit(1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(LogGrouping.dayTitle(group.day)), \(totalText)"
        )
    }
}

// MARK: - List
