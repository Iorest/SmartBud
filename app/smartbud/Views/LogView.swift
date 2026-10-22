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
    private var allTransactions: [TransactionModel]

    @Query(sort: [SortDescriptor(\TransferModel.date, order: .reverse)])
    var allTransfers: [TransferModel]

    @Environment(TransactionViewModel.self) var transactionVM
    @Environment(CategoryViewModel.self) private var categoryVM
    @Environment(\.scenePhase) private var scenePhase

    @AppStorage("currency", store: .appGroup) var currency: String = Locale.current.currency?.identifier ?? "USD"
    @AppStorage("showCents", store: .appGroup) var showCents: Bool = true
    @AppStorage("showUpcomingTransactions", store: .appGroup) var showUpcoming: Bool = true
    @AppStorage("showUpcomingTransactionsWhenUpcoming", store: .appGroup) var showSoon: Bool = false

    var launchSearch: Bool
    /// Invoked by the empty state's primary button ("Add Entry").
    var onAdd: () -> Void = {}

    @State var searchText = ""
    @State private var searchPresented = false
    @State private var navBarText = ""

    // Batch selection
    @State private var isSelecting = false
    @State private var selectedIDs: Set<UUID> = []
    @State private var showBatchDelete = false

    @State var filter = FilterType.all
    @State private var categoryFilter: CategoryModel?
    @State private var dateFilter = Date.now
    @State private var weekFilter = Date.now
    @State private var monthFilter = Date.now
    @State private var income = false

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
            if !allTransactions.isEmpty {
                #if os(iOS)
                ToolbarItem(placement: .topBarLeading) { selectionToggle }
                #else
                ToolbarItem(placement: .navigation) { selectionToggle }
                #endif
            }

            ToolbarItemGroup(placement: .primaryAction) {
                filterMenu
                Button {
                    onAdd()
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel(Text(String.appLocalized("Add New Transaction")))
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
        .focusedSceneValue(\.searchLog, { searchPresented = true })
        .onOpenURL { url in
            if url.host == "search" { searchPresented = true }
        }
        .onChange(of: scenePhase) { _, new in
            if new == .active,
               !NSUbiquitousKeyValueStore.default.bool(forKey: "icloud_sync") {
                transactionVM.updateAllRecurring()
            }
        }
        .onAppear {
            categoryVM.load()
            if !NSUbiquitousKeyValueStore.default.bool(forKey: "icloud_sync") {
                transactionVM.updateAllRecurring()
            }
        }
    }

    // MARK: - List

    private var logList: some View {
        Group {
            if visibleEntries.isEmpty {
                emptyResultView
            } else {
                LogTransactionList(
                    entries: visibleEntries,
                    future: filter == .upcoming,
                    upcoming: upcomingTransactions,
                    isSelecting: isSelecting,
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
        guard includeUpcoming, searchText.isEmpty else { return [] }

        let calendar = Calendar.current
        let horizon = calendar.date(byAdding: .weekOfYear, value: 2, to: calendar.startOfDay(for: .now))
            ?? .distantFuture

        return allTransactions
            .filter { transaction in
                guard transaction.recurringType > 0 || transaction.wrappedDate > .now else { return false }
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
            items = pastTransactions.filter { $0.income == income }
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
            let interval = Calendar.current.dateInterval(of: .weekOfYear, for: weekFilter)
            items = pastTransactions.filter {
                interval?.contains($0.wrappedDate) ?? false
            }
        case .month:
            let interval = Calendar.current.dateInterval(of: .month, for: monthFilter)
            items = pastTransactions.filter {
                interval?.contains($0.wrappedDate) ?? false
            }
        case .all:
            items = pastTransactions
        }

        if filter == .all, !searchText.isEmpty {
            items = items.filter(matchesSearch)
        }

        return items.sorted { $0.wrappedDate > $1.wrappedDate }
    }

}

extension LogView {

    // MARK: - Batch selection

    private var selectedTransactions: [TransactionModel] {
        visibleTransactions.filter { selectedIDs.contains($0.id) }
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

extension LogView {

    @ViewBuilder
    private var stepperBar: some View {
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
        .padding(.horizontal, SBSpace.medium)
        .padding(.vertical, SBSpace.extraSmall)
        .background(.bar)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }
}
