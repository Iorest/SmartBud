//
//  LogView+Entries.swift
//  smartbud
//
//  Ledger row assembly and search matching for the log screen.
//

import Foundation
import SwiftData
import SwiftUI

extension LogView {

    /// Calendar with the user's week/month start preferences. The list filter
    /// and the stepper above it must use the same definition, otherwise the
    /// header says "this week" and the rows belong to a different one.
    var periodCalendar: Calendar {
        AppPeriod.configuredCalendar(
            firstWeekday: UserDefaults.appGroup.integer(forKey: "firstWeekday"))
    }

    var monthStartDay: Int {
        UserDefaults.appGroup.integer(forKey: "firstDayOfMonth")
    }

    /// Applies a search deep link that arrived before this tab existed (there
    /// is no `onChange` to catch it in that case).
    func applyPendingSearch() {
        guard let query = launchSearchQuery, !query.isEmpty, searchText.isEmpty else { return }
        filter = .all
        searchText = query
        searchPresented = true
    }

    /// Ledger rows: transactions plus transfers. Transfers only belong in the
    /// unfiltered view — a category or date filter has no meaning for them.
    var visibleEntries: [LogEntry] {
        var entries = visibleTransactions.map(LogEntry.transaction)

        if filter == .all {
            let transferEntries = allTransfers
                .filter { $0.wrappedDate <= .now }
                .filter { searchText.isEmpty || matchesTransferSearch($0) }
                .map(LogEntry.transfer)
            entries.append(contentsOf: transferEntries)
        }

        return entries.sorted { $0.date > $1.date }
    }

    func matchesTransferSearch(_ transfer: TransferModel) -> Bool {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return true }

        if transfer.wrappedNote.localizedStandardContains(query) { return true }
        if (transfer.source?.wrappedName ?? "").localizedStandardContains(query) { return true }
        if (transfer.destination?.wrappedName ?? "").localizedStandardContains(query) { return true }

        return String(format: "%.2f", transfer.amount).contains(query)
    }

    func matchesSearch(_ transaction: TransactionModel) -> Bool {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return true }

        if transaction.wrappedNote.localizedStandardContains(query) { return true }
        if transaction.wrappedCategoryName.localizedStandardContains(query) { return true }
        if (transaction.category?.wrappedEmoji ?? "").contains(query) { return true }

        let amount = String(format: "%.2f", transaction.amount)
        return amount.contains(query)
    }

    @ViewBuilder
    var stepperBar: some View {
        VStack(spacing: 2) {
            Group {
                switch filter {
                case .category:
                    CategoryStepperView(categoryFilter: $categoryFilter)
                case .day:
                    DateStepperView(date: $dateFilter)
                case .week:
                    WeekStepperView(showingDate: $weekFilter)
                case .month:
                    MonthStepperView(showingDate: $monthFilter)
                case .type:
                    IncomeFilterToggleView(income: $income)
                default:
                    EmptyView()
                }
            }

            if showsPeriodTotals {
                LogPeriodTotals(entries: visibleTransactions,
                                currency: currency,
                                showCents: showCents)
            }
        }
        .padding(.horizontal, SBSpace.medium)
        .padding(.vertical, SBSpace.extraSmall)
        .background(.bar)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    /// The header card (with its own period menu) is only shown for "all".
    /// Without this line a filtered list had no totals at all, so "how much
    /// did I spend that week" was unanswerable on the screen showing the week.
    var showsPeriodTotals: Bool {
        switch filter {
        case .day, .week, .month, .category:
            return !visibleTransactions.isEmpty
        default:
            return false
        }
    }
}
