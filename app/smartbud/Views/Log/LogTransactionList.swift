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

struct LogTransactionRow: View {
    let transaction: TransactionModel
    var future: Bool = false

    @AppStorage("showCents", store: .appGroup) private var showCents: Bool = true
    @AppStorage("currency", store: .appGroup) private var currency: String = Locale.current.currency?.identifier ?? "USD"
    @AppStorage("swapTimeLabel", store: .appGroup) private var swapTimeLabel: Bool = false
    @AppStorage("showExpenseOrIncomeSign", store: .appGroup) private var showExpenseOrIncomeSign: Bool = true

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var amountText: String {
        LogGrouping.currency(
            transaction.amount,
            code: currency,
            showCents: showCents,
            signed: showExpenseOrIncomeSign,
            income: transaction.income
        )
    }

    private var subtitle: String {
        if future {
            return dateFormatter(date: transaction.wrappedDate > .now
                                 ? transaction.wrappedDate
                                 : transaction.nextTransactionDate)
        }
        if swapTimeLabel {
            return transaction.wrappedCategoryName
        }
        return transaction.wrappedDate.formatted(
            Date.FormatStyle(locale: Locale.appLocale).hour().minute()
        )
    }

    private var amountColor: Color {
        if future {
            return Color.SubtitleText
        }
        return transaction.income ? Color.IncomeGreen : Color.PrimaryText
    }

    var body: some View {
        HStack(spacing: SBSpace.s) {
            EmojiLogView(
                emoji: transaction.category?.wrappedEmoji ?? "",
                colour: transaction.category?.wrappedColour ?? "#FFFFFF",
                future: future
            )
            .fixedSize(horizontal: true, vertical: true)
            .overlay(alignment: .bottomTrailing) {
                if transaction.recurringType > 0 {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color.SubtitleText)
                        .padding(3)
                        .background(Color.SecondaryBackground, in: RoundedRectangle(cornerRadius: SBRadius.pill))
                        .offset(x: 5, y: 5)
                        .accessibilityHidden(true)
                }
            }

            if dynamicTypeSize.isAccessibilitySize {
                // At accessibility sizes the note and the amount each need a
                // full line; side by side they both truncate.
                VStack(alignment: .leading, spacing: 4) {
                    nameAndTime
                    amountLabel
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            } else {
                nameAndTime
                    .frame(maxWidth: .infinity, alignment: .leading)
                amountLabel
            }
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }

    private var nameAndTime: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(transaction.wrappedNote.isEmpty
                 ? (transaction.category?.wrappedName ?? String.appLocalized("Unknown"))
                 : transaction.wrappedNote)
                .font(.body)
                .foregroundStyle(future ? Color.SubtitleText : Color.PrimaryText)
                .lineLimit(2)

            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(Color.SubtitleText)
                .lineLimit(1)
        }
    }

    private var amountLabel: some View {
        Text(amountText)
            .font(.body.monospacedDigit())
            .foregroundStyle(amountColor)
            .lineLimit(1)
            .layoutPriority(1)
            .accessibilityLabel(amountText)
    }
}

// MARK: - Day header

struct LogDayHeaderRow: View {
    let group: LogDayGroup

    @AppStorage("showCents", store: .appGroup) private var showCents: Bool = true
    @AppStorage("currency", store: .appGroup) private var currency: String = Locale.current.currency?.identifier ?? "USD"

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
            Spacer(minLength: SBSpace.xs)
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

struct LogTransactionList<Header: View>: View {
    var transactions: [TransactionModel]
    var future: Bool = false
    /// Repeating/future rows shown in their own section above the months.
    var upcoming: [TransactionModel] = []
    var header: Header

    @Environment(TransactionViewModel.self) private var transactionVM
    @Environment(OverallTransactionManager.self) private var transactionManager

    init(
        transactions: [TransactionModel],
        future: Bool = false,
        upcoming: [TransactionModel] = [],
        @ViewBuilder header: () -> Header
    ) {
        self.transactions = transactions
        self.future = future
        self.upcoming = upcoming
        self.header = header()
    }

    private var months: [LogMonthGroup] {
        LogGrouping.months(transactions)
    }

    /// A repeating transaction whose next occurrence is in the past can only
    /// be stopped, not deleted, so it must not be full-swipe deletable.
    private func stopsRecurring(_ transaction: TransactionModel, future: Bool? = nil) -> Bool {
        let isFuture = future ?? self.future
        return isFuture && transaction.wrappedDate < .now && transaction.recurringType > 0
    }

    var body: some View {
        List {
            header
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

            if !upcoming.isEmpty {
                Section {
                    ForEach(upcoming) { transaction in
                        row(transaction, isFuture: true)
                    }
                } header: {
                    Text(String.appLocalized("UPCOMING"))
                }
            }

            #if os(macOS)
            // macOS renders a nested `ForEach` + `Section` list unreliably
            // (the same month header appeared twice). Flatten the hierarchy
            // into one row array with stable string identities instead.
            ForEach(flatRows) { item in
                switch item {
                case .month(let date):
                    Text(date, format: .dateTime.year().month(.wide))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.SubtitleText)
                        .padding(.top, SBSpace.s)
                        .padding(.horizontal, SBSpace.m)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                case .day(let day):
                    LogDayHeaderRow(group: day)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 2, trailing: 16))
                case .transaction(let transaction):
                    row(transaction)
                }
            }
            #else
            ForEach(months) { month in
                Section {
                    monthRows(month)
                } header: {
                    Text(month.month, format: .dateTime.year().month(.wide))
                        .font(.subheadline.weight(.semibold))
                }
            }
            #endif
        }
        #if os(macOS)
        .listStyle(.inset)
        #else
        .listStyle(.insetGrouped)
        .listSectionSpacing(16)
        #endif
        .scrollContentBackground(.hidden)
        .contentMargins(.top, 0, for: .scrollContent)
    }

    #if os(macOS)
    private enum FlatRow: Identifiable {
        case month(Date)
        case day(LogDayGroup)
        case transaction(TransactionModel)

        var id: String {
            switch self {
            case .month(let date): return "m-\(date.timeIntervalSince1970)"
            case .day(let group): return "d-\(group.day.timeIntervalSince1970)"
            case .transaction(let transaction): return "t-\(transaction.id.uuidString)"
            }
        }
    }

    private var flatRows: [FlatRow] {
        months.flatMap { month in
            [FlatRow.month(month.month)] + month.days.flatMap { day in
                [FlatRow.day(day)] + day.transactions.map { FlatRow.transaction($0) }
            }
        }
    }
    #endif

    @ViewBuilder
    private func monthRows(_ month: LogMonthGroup) -> some View {
        ForEach(month.days) { day in
            LogDayHeaderRow(group: day)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 2, trailing: 16))

            ForEach(day.transactions) { transaction in
                row(transaction)
            }
        }
    }

    private func row(_ transaction: TransactionModel, isFuture: Bool? = nil) -> some View {
        let futureRow = isFuture ?? future

        return Button {
            transactionManager.toEdit = transaction
        } label: {
            LogTransactionRow(transaction: transaction, future: futureRow)
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing, allowsFullSwipe: !stopsRecurring(transaction, future: futureRow)) {
            Button(role: .destructive) {
                remove(transaction, future: futureRow)
            } label: {
                Label(String.appLocalized("Delete"), systemImage: "trash")
            }

            Button {
                transactionManager.toEdit = transaction
            } label: {
                Label(String.appLocalized("Edit"), systemImage: "pencil")
            }
            .tint(.accentColor)
        }
        .contextMenu {
            if transaction.recurringType > 0 {
                Button {
                    transactionVM.stopRecurring(transaction)
                } label: {
                    Label(String.appLocalized("Stop Recurring"), systemImage: "xmark")
                }
            }

            Button {
                transactionManager.toEdit = transaction
            } label: {
                Label(String.appLocalized("Edit"), systemImage: "pencil")
            }

            if !stopsRecurring(transaction, future: futureRow) {
                Button(role: .destructive) {
                    remove(transaction, future: futureRow)
                } label: {
                    Label(String.appLocalized("Delete"), systemImage: "trash")
                }
            }
        }
    }

    private func remove(_ transaction: TransactionModel, future: Bool? = nil) {
        if stopsRecurring(transaction, future: future) {
            withAnimation {
                transactionVM.stopRecurring(transaction)
            }
        } else {
            // Staged so the undo banner can restore it; the view model owns
            // the commit timer.
            withAnimation {
                transactionVM.stageDelete(transaction)
            }
        }
    }
}

extension LogTransactionList where Header == EmptyView {
    init(transactions: [TransactionModel], future: Bool = false, upcoming: [TransactionModel] = []) {
        self.init(transactions: transactions, future: future, upcoming: upcoming) { EmptyView() }
    }
}
