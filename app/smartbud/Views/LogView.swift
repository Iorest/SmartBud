//
//  LogView.swift
//  smartbud
//
//  Native log: `NavigationStack` + `List`, months as sections, day headers,
//  and real search. The previous version stacked a custom scroll view,
//  hand-drawn dividers, a bespoke swipe gesture and a separate search screen.
//

import Foundation
import SwiftData
import SwiftUI

struct LogView: View {
    @Query(sort: [SortDescriptor(\TransactionModel.date, order: .reverse)])
    private var fetchedTransactions: [TransactionModel]

    @Query(sort: [SortDescriptor(\TransferModel.date, order: .reverse)])
    private var fetchedTransfers: [TransferModel]

    @Environment(BookState.self) private var bookState
    @Environment(TransactionViewModel.self) var transactionVM
    @Environment(CategoryViewModel.self) private var categoryVM
    @Environment(\.scenePhase) private var scenePhase

    // The queries cover the whole store; these computed arrays are the only
    // rows the log (and its extensions) are allowed to render or mutate.
    private var allTransactions: [TransactionModel] {
        BookScope.scoped(fetchedTransactions, \.bookID, selected: bookState.currentID)
    }

    var allTransfers: [TransferModel] {
        fetchedTransfers.filter { BookScope.matches($0, selected: bookState.currentID) }
    }

    @AppStorage("currency", store: .appGroup) var currency: String = Locale.current.currency?.identifier ?? "USD"
    @AppStorage("showCents", store: .appGroup) var showCents: Bool = true
    @AppStorage("showUpcomingTransactions", store: .appGroup) var showUpcoming: Bool = true
    @AppStorage("showUpcomingTransactionsWhenUpcoming", store: .appGroup) var showSoon: Bool = false

    var launchSearch: Bool
    /// Query carried by `smartbud://search?q=…`. Applied when it arrives, so a
    /// deep link does not just focus an empty field.
    var launchSearchQuery: String?

    /// Compact layouts own the book picker in this toolbar; the wide layout
    /// puts it in the sidebar instead, so it appears exactly once.
    var showsBookSwitcher = true
    /// Invoked by the empty state's primary button ("Add Entry").
    var onAdd: () -> Void = {}

    @State var searchText = ""
    @State var searchPresented = false
    @State private var navBarText = ""

    // Batch selection
    @State private var isSelecting = false
    @State private var selectedIDs: Set<UUID> = []
    @State private var showBatchDelete = false

    @State var filter = FilterType.all
    @State var categoryFilter: CategoryModel?
    @State var dateFilter = Date.now
    @State var weekFilter = Date.now
    @State var monthFilter = Date.now
    @State var income = false

    private var currencySymbol: String {
        Locale.appCurrencySymbol(forCurrencyCode: currency)
    }

    // MARK: - Content

    private var content: some View {
        Group {
            if allTransactions.isEmpty {
                SBEmptyState(
                    systemImage: "list.bullet.rectangle.portrait",
                    title: String.appLocalized("Your Log is Empty"),
                    message: String.appLocalized("Record your first expense or income to get started"),
                    actionTitle: String.appLocalized("Add Entry"),
                    action: onAdd
                )
            } else {
                logList
            }
        }
        .navigationTitle(String.appLocalized("Log"))
        #if os(iOS)
        // Inline keeps the title visible while the filter bar is pinned above
        // the list; a large title would collapse as soon as the inset appears.
        .navigationBarTitleDisplayMode(.inline)
        #endif
        #if os(iOS)
        .searchable(
            text: $searchText,
            isPresented: $searchPresented,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: Text(String.appLocalized("Search notes, categories, amounts"))
        )
        #else
        .searchable(
            text: $searchText,
            isPresented: $searchPresented,
            prompt: Text(String.appLocalized("Search notes, categories, amounts"))
        )
        #endif
        .toolbar {
            #if os(iOS)
            ToolbarItemGroup(placement: .topBarLeading) {
                if showsBookSwitcher { BookSwitcherMenu() }
                if !allTransactions.isEmpty { selectionToggle }
            }
            #else
            ToolbarItemGroup(placement: .navigation) {
                if showsBookSwitcher { BookSwitcherMenu() }
                if !allTransactions.isEmpty { selectionToggle }
            }
            #endif

            ToolbarItemGroup(placement: .primaryAction) {
                filterMenu
                Button {
                    onAdd()
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel(Text(String.appLocalized("Add New Transaction")))
                .accessibilityHint(Text(String.appLocalized("Add a new transaction")))
                .accessibilityIdentifier(AccessibilityID.logAddButton)
            }
        }
        .alert(
            String.appFormatted("Delete %lld transactions?", selectedIDs.count),
            isPresented: $showBatchDelete
        ) {
            Button(String.appLocalized("Delete"), role: .destructive) {
                transactionVM.delete(selectedTransactions)
                withAnimation(.easeInOut(duration: 0.2)) {
                    selectedIDs.removeAll()
                    isSelecting = false
                }
            }
            Button(String.appLocalized("Cancel"), role: .cancel) {}
        } message: {
            Text(String.appLocalized("This action cannot be undone."))
        }
        .onChange(of: launchSearch) { _, newValue in
            if newValue { searchPresented = true }
        }
        .onChange(of: launchSearchQuery) { _, query in
            guard let query, !query.isEmpty else { return }
            filter = .all
            searchText = query
            searchPresented = true
        }
        .focusedSceneValue(\.searchLog, { searchPresented = true })
        .onOpenURL { url in
            guard let request = DeepLinkRequest(url: url), request.action == .search else { return }
            if let query = request.searchQuery {
                filter = .all
                searchText = query
            }
            searchPresented = true
        }
        .onChange(of: scenePhase) { _, new in
            if new == .active,
               !NSUbiquitousKeyValueStore.default.bool(forKey: "icloud_sync") {
                transactionVM.updateAllRecurring()
            }
        }
        .onAppear {
            applyPendingSearch()
            categoryVM.load()
            if !NSUbiquitousKeyValueStore.default.bool(forKey: "icloud_sync") {
                transactionVM.updateAllRecurring()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .bookDidChange)) { _ in
            // Search text and batch selection refer to rows in the old book.
            searchText = ""
            selectedIDs.removeAll()
            isSelecting = false
            categoryFilter = nil
        }
    }

    // MARK: - List

    private var logList: some View {
        Group {
            // Upcoming rows live in their own section, not in `entries`, so an
            // empty entry list is not an empty screen when they exist.
            if visibleEntries.isEmpty && upcomingTransactions.isEmpty {
                emptyResultView
            } else {
                LogTransactionList(
                    entries: visibleEntries,
                    future: filter == .upcoming,
                    upcoming: upcomingTransactions,
                    isSelecting: isSelecting,
                    showsMonthHeader: filter != .month,
                    selection: $selectedIDs
                ) {
                    if filter == .all && searchText.isEmpty {
                        LogInsightsView(
                            navBarText: $navBarText,
                            showCents: showCents,
                            currencySymbol: currencySymbol
                        )
                    }
                }
            }
        }
        // The stepper stays put when a period has no entries: otherwise the
        // empty state takes away the only way to step to another day/week.
        .safeAreaInset(edge: .top, spacing: 0) {
            if showsStepper {
                stepperBar
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if isSelecting && !selectedIDs.isEmpty {
                LogSelectionBar(
                    count: selectedIDs.count,
                    expenseCategories: categoryVM.expenseCategories,
                    incomeCategories: categoryVM.incomeCategories,
                    onPick: moveSelection,
                    onDelete: { showBatchDelete = true }
                )
            }
        }
    }

    @ViewBuilder
    private var emptyResultView: some View {
        if !searchText.isEmpty {
            ContentUnavailableView.search(text: searchText)
        } else {
            ContentUnavailableView {
                Label(String.appLocalized("No entries found."), systemImage: "tray")
            } description: {
                Text(String.appLocalized("Try a different filter or add a new entry."))
            } actions: {
                Button(String.appLocalized("Clear Filter")) {
                    filter = .all
                    categoryFilter = nil
                    searchText = ""
                }
                .buttonStyle(.bordered)
            }
        }
    }

    // MARK: - Filters

    // MARK: - Data

    /// The ledger up to now. Future occurrences live in the Upcoming section
    /// instead of appearing twice.
    private var pastTransactions: [TransactionModel] {
        allTransactions.filter { $0.wrappedDate <= .now }
    }

    private var upcomingTransactions: [TransactionModel] {
        let includeUpcoming = filter == .upcoming || (filter == .all && showUpcoming)
        guard includeUpcoming else { return [] }

        let calendar = Calendar.current
        let horizon = calendar.date(byAdding: .weekOfYear, value: 2, to: calendar.startOfDay(for: .now))
            ?? .distantFuture

        return allTransactions
            .filter { transaction in
                guard transaction.recurringType > 0 || transaction.wrappedDate > .now else { return false }
                guard matchesSearch(transaction) else { return false }
                guard showSoon else { return true }
                return nextDate(for: transaction) < horizon
            }
            .sorted { nextDate(for: $0) > nextDate(for: $1) }
    }

    private func nextDate(for transaction: TransactionModel) -> Date {
        transaction.wrappedDate > .now ? transaction.wrappedDate : transaction.nextTransactionDate
    }

    var visibleTransactions: [TransactionModel] {
        var items: [TransactionModel]

        switch filter {
        case .upcoming:
            items = []
        case .recurring:
            items = pastTransactions.filter(\.onceRecurring)
        case .type:
            // Balance adjustments carry the income flag but are neither income
            // nor expense; keep them out of this filter.
            items = pastTransactions.filter { $0.income == income && !$0.adjustment }
        case .category:
            if let categoryFilter {
                items = pastTransactions.filter { $0.category?.id == categoryFilter.id }
            } else {
                items = pastTransactions
            }
        case .day:
            items = pastTransactions.filter {
                Calendar.current.isDate($0.wrappedDate, inSameDayAs: dateFilter)
            }
        case .week:
            let range = AppPeriod.weekRange(containing: weekFilter, calendar: periodCalendar)
            items = pastTransactions.filter {
                $0.wrappedDate >= range.start && $0.wrappedDate < range.end
            }
        case .month:
            let range = AppPeriod.monthRange(containing: monthFilter,
                                             startDay: monthStartDay,
                                             calendar: periodCalendar)
            items = pastTransactions.filter {
                $0.wrappedDate >= range.start && $0.wrappedDate < range.end
            }
        case .all:
            items = pastTransactions
        }

        // Search narrows whatever filter is active; it used to apply only on
        // "All", so typing in a week view left the rows untouched.
        if !searchText.isEmpty {
            items = items.filter(matchesSearch)
        }

        return items.sorted { $0.wrappedDate > $1.wrappedDate }
    }

}

extension LogView {

    // MARK: - Batch selection

    /// Resolve from the whole ledger, not the current filter: changing the
    /// filter after selecting used to leave the confirmation counting rows
    /// that the delete call could no longer see.
    private var selectedTransactions: [TransactionModel] {
        allTransactions.filter { selectedIDs.contains($0.id) }
    }

    private var selectionToggle: some View {
        Button(isSelecting ? String.appLocalized("Done") : String.appLocalized("Edit")) {
            withAnimation(.easeInOut(duration: 0.2)) {
                isSelecting.toggle()
                selectedIDs.removeAll()
            }
        }
    }

    private func moveSelection(to category: CategoryModel) {
        transactionVM.setCategory(category, for: selectedTransactions)
        withAnimation(.easeInOut(duration: 0.2)) {
            selectedIDs.removeAll()
            isSelecting = false
        }
    }

    private var showsStepper: Bool {
        switch filter {
        case .category, .day, .week, .month, .type:
            return true
        case .all, .recurring, .upcoming:
            return false
        }
    }

    private var filterMenu: some View {
        Menu {
            Picker(String.appLocalized("Filter"), selection: $filter) {
                ForEach(FilterType.allCases, id: \.self) { option in
                    Label(
                        LocalizedStringKey(option.rawValue),
                        systemImage: FilterType.imageDictionary[option] ?? "line.3.horizontal.decrease"
                    )
                    .tag(option)
                }
            }

            if filter != .all {
                Divider()
                Button(String.appLocalized("Clear Filter"), systemImage: "xmark.circle") {
                    filter = .all
                }
            }
        } label: {
            Image(systemName: filter == .all
                  ? "line.3.horizontal.decrease"
                  : "line.3.horizontal.decrease.circle.fill")
        }
        .accessibilityLabel(Text(String.appLocalized("Filter")))
    }

    var body: some View {
        #if os(iOS)
        NavigationStack {
            content
        }
        #else
        content
        #endif
    }
}
