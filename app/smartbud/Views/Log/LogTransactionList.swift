//
//  LogTransactionList.swift
//  smartbud
//
//  One `List`, one section per month, a day header per day, real
//  `swipeActions`. Rows are `LogEntry` values so account transfers can sit
//  in the same timeline as transactions.
//

import SwiftData
import SwiftUI

// MARK: - Grouping

/// One row in the ledger: either a transaction or an account transfer.
/// Transfers carry no net amount — moving money between your own accounts
/// must not change income or spend totals.
enum LogEntry: Identifiable {
    case transaction(TransactionModel)
    case transfer(TransferModel)

    var id: UUID {
        switch self {
        case .transaction(let txn): return txn.id
        case .transfer(let transfer): return transfer.id
        }
    }

    var date: Date {
        switch self {
        case .transaction(let txn): return txn.wrappedDate
        case .transfer(let transfer): return transfer.wrappedDate
        }
    }

    var netAmount: Double {
        switch self {
        // Same policy as the statistics totals: claims and balance
        // adjustments move the account but not the day's income/spend.
        case .transaction(let txn): return txn.signedBaseAmount
        case .transfer: return 0
        }
    }
}

struct LogDayGroup: Identifiable {
    let day: Date
    let entries: [LogEntry]

    var id: Date { day }

    var netTotal: Double {
        entries.reduce(0) { $0 + $1.netAmount }
    }
}

struct LogMonthGroup: Identifiable {
    let month: Date
    let days: [LogDayGroup]

    var id: Date { month }
}

enum LogGrouping {
    static func months(_ entries: [LogEntry], calendar: Calendar = .current) -> [LogMonthGroup] {
        let byDay = Dictionary(grouping: entries) { calendar.startOfDay(for: $0.date) }

        let days = byDay.map { day, items in
            LogDayGroup(
                day: day,
                entries: items.sorted { $0.date > $1.date }
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

// MARK: - List

struct LogTransactionList<Header: View>: View {
    var entries: [LogEntry]
    var future: Bool = false
    /// Repeating/future rows shown in their own section above the months.
    var upcoming: [TransactionModel] = []
    /// Multi-select mode: rows show a selection circle instead of opening.
    var isSelecting: Bool = false
    /// False when the filter itself names the month: the stepper above already
    /// says "2026年10月", so repeating it as a section header reads like a bug.
    var showsMonthHeader: Bool = true
    @Binding var selection: Set<UUID>
    var header: Header

    @State var selectionHaptic = 0

    @Environment(TransactionViewModel.self) var transactionVM
    @Environment(OverallTransactionManager.self) var transactionManager
    @Environment(AccountViewModel.self) var accountVM

    @State var transferToDelete: TransferModel?

    init(
        entries: [LogEntry],
        future: Bool = false,
        upcoming: [TransactionModel] = [],
        isSelecting: Bool = false,
        showsMonthHeader: Bool = true,
        selection: Binding<Set<UUID>>? = nil,
        @ViewBuilder header: () -> Header
    ) {
        self.entries = entries
        self.future = future
        self.upcoming = upcoming
        self.isSelecting = isSelecting
        self.showsMonthHeader = showsMonthHeader
        _selection = selection ?? .constant([])
        self.header = header()
    }

    private var months: [LogMonthGroup] {
        LogGrouping.months(entries)
    }

    /// A repeating transaction whose next occurrence is in the past can only
    /// be stopped, not deleted, so it must not be full-swipe deletable.
    func stopsRecurring(_ transaction: TransactionModel, future: Bool? = nil) -> Bool {
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
                        .padding(.top, SBSpace.small)
                        .padding(.horizontal, SBSpace.medium)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                case .day(let day):
                    LogDayHeaderRow(group: day)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 2, trailing: 16))
                case .entry(let entry):
                    entryRow(entry)
                }
            }
            #else
            ForEach(months) { month in
                Section {
                    monthRows(month)
                } header: {
                    if showsMonthHeader {
                        Text(month.month, format: .dateTime.year().month(.wide))
                            .font(.subheadline.weight(.semibold))
                    }
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
        .sensoryFeedback(.selection, trigger: selectionHaptic)
        .alert(
            String.appLocalized("Delete this transfer?"),
            isPresented: Binding(
                get: { transferToDelete != nil },
                set: { if !$0 { transferToDelete = nil } }
            )
        ) {
            Button(String.appLocalized("Delete"), role: .destructive) {
                if let transferToDelete {
                    accountVM.deleteTransfer(transferToDelete)
                }
                transferToDelete = nil
            }
            Button(String.appLocalized("Cancel"), role: .cancel) { transferToDelete = nil }
        } message: {
            Text(String.appLocalized("Both account balances go back to what they were."))
        }
    }

    #if os(macOS)
    private enum FlatRow: Identifiable {
        case month(Date)
        case day(LogDayGroup)
        case entry(LogEntry)

        var id: String {
            switch self {
            case .month(let date): return "m-\(date.timeIntervalSince1970)"
            case .day(let group): return "d-\(group.day.timeIntervalSince1970)"
            case .entry(let entry): return "e-\(entry.id.uuidString)"
            }
        }
    }

    private var flatRows: [FlatRow] {
        months.flatMap { month in
            // The month filter's stepper already names the month; repeating it
            // as a section header read like a duplicate (iOS suppressed it,
            // macOS did not).
            let header: [FlatRow] = showsMonthHeader ? [.month(month.month)] : []
            return header + month.days.flatMap { day in
                [FlatRow.day(day)] + day.entries.map { FlatRow.entry($0) }
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

            ForEach(day.entries) { entry in
                entryRow(entry)
            }
        }
    }

    @ViewBuilder
    private func entryRow(_ entry: LogEntry) -> some View {
        switch entry {
        case .transaction(let transaction):
            row(transaction)
        case .transfer(let transfer):
            transferRow(transfer)
        }
    }
}
