//
//  HomeView.swift
//  smartbud
//
//  Created by Iorest on 20/5/22.
//

import Foundation
import Observation
import SwiftData
import SwiftUI

@MainActor
@Observable
class OverallTransactionManager {
    var toEdit: TransactionModel?
    var toDelete: TransactionModel?
    /// The refund sheet: a new refund for the original, or an existing row to
    /// edit. Kept apart from `toEdit` because a refund is created without
    /// going through the transaction form.
    var toRefund: RefundTarget?
    /// The write-off sheet: giving up on a claim that will never be paid back.
    var toBadDebt: BadDebtTarget?
    var showPopup: Bool = false
    var future: Bool = false
}

/// Reusable ledger picker. Switching here changes the single app-wide
/// selection, so every screen follows at once (no per-tab book state).
struct BookSwitcherMenu: View {
    @Environment(BookState.self) private var bookState

    var body: some View {
        Menu {
            ForEach(bookState.availableBooks.filter { !$0.archived }, id: \.id) { book in
                Button {
                    bookState.select(book.id)
                } label: {
                    HStack {
                        Text(book.name)
                        Spacer()
                        if bookState.isCurrent(book.id) {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Label(bookState.currentName, systemImage: "book.closed")
        }
    }
}

struct HomeView: View {
    @Environment(AppLockViewModel.self) var appLockVM
    @Environment(BookState.self) private var bookState
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif

    @State var transactionManager = OverallTransactionManager()
    @Environment(TransactionViewModel.self) var transactionVM
    @Environment(CategoryViewModel.self) var categoryVM
    @Environment(AccountViewModel.self) var accountVM
    @Environment(InsightsViewModel.self) var insightsVM
    @Environment(\.openURL) var openURL

    @State var currentTab = "Log"
    /// One-shot day focus from the statistics calendar. The token makes two
    /// taps on the same day separate requests.
    @State private var logDayRequest: LogDayRequest?
    @State private var logDayRequestToken = 0

    private func focusLogDay(_ date: Date) {
        logDayRequestToken += 1
        logDayRequest = LogDayRequest(date: date, token: logDayRequestToken)
        currentTab = "Log"
    }

    var topEdge: CGFloat

    @State var fromURL1: Bool = false
    @State var fromURL2: Bool = false
    @State var fromURL3: Bool = false
    @State var fromURL4: Bool = false

    @State var launchAdd: Bool = false
    @State var launchSearch: Bool = false
    @State var launchSearchQuery: String?
    /// "New expense" arrived while the privacy lock was up; replay it after
    /// the unlock instead of dropping it.
    @State var pendingAddAfterUnlock = false

    @State var counter = 0
    @State private var showConfetti = false
    var isInFallbackMode: Bool = false

    // Floating add button (replaces the custom tab bar's centre button).
    @State var addTransaction = false
    @State private var transactionCountBeforeAdd = 0
    @Query private var fetchedTransactions: [TransactionModel]
    @AppStorage("confetti", store: .appGroup) private var confetti: Bool = false
    @AppStorage("firstTransactionViewLaunch", store: .appGroup) private var firstLaunch: Bool = true
    /// "秒开": open the entry form straight after launch.
    @AppStorage("launchIntoEntry", store: .appGroup) private var launchIntoEntry: Bool = false

    /// Confetti compares this book's count before and after the entry sheet;
    /// another ledger's rows must not fire (or suppress) the celebration.
    private var transactions: [TransactionModel] {
        BookScope.scoped(fetchedTransactions, \.bookID, selected: bookState.currentID)
    }

    init(topEdge: CGFloat, isInFallbackMode: Bool = false) {
        self.topEdge = topEdge
        self.isInFallbackMode = isInFallbackMode
        #if DEBUG
        // QA hook: `SIMCTL_CHILD_START_TAB=Insights` opens straight on a tab
        // for screenshot/UI verification. Debug builds only.
        if let tab = ProcessInfo.processInfo.environment["START_TAB"],
           ["Log", "Insights", "Budget", "Settings"].contains(tab) {
            _currentTab = State(initialValue: tab)
        }
        #endif
    }

    /// Wide layouts (Mac, iPad in regular width) use a real sidebar instead of
    /// the compact tab strip. The detail column keeps an 860pt reading width.
    private var splitShell: some View {
        NavigationSplitView {
            List {
                if !appLockVisible {
                    Section {
                        BookSwitcherMenu()
                    }
                }
                ForEach(Self.sections) { section in
                    Button {
                        currentTab = section.id
                    } label: {
                        Label(String.appLocalized(section.titleKey), systemImage: section.symbol)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(
                        currentTab == section.id
                            ? Color.accentColor.opacity(0.15)
                            : Color.clear
                    )
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 180, ideal: 210, max: 260)
        } detail: {
            splitDetail
        }
        .navigationSplitViewStyle(.balanced)
        .environment(transactionManager)
    }

    @ViewBuilder
    private var splitDetail: some View {
        Group {
            switch currentTab {
            case "Insights":
                InsightsView(onAdd: { addTransaction = true },
                             onSelectDay: focusLogDay)
            case "Budget":
                BudgetView()
            case "Settings":
                SettingsView()
            default:
                LogView(launchSearch: launchSearch,
                        launchSearchQuery: launchSearchQuery,
                        dayRequest: logDayRequest,
                        showsBookSwitcher: !isWideLayout && !appLockVisible,
                        onAdd: { addTransaction = true })
            }
        }
        .frame(maxWidth: 860)
        .frame(maxWidth: .infinity)
        .background(AppBackground())
    }

    /// Explicit undo affordance for a staged delete. Replaces the previous
    /// AlertToast, whose tap handler was swallowed on iOS 26 so "undo" only
    /// dismissed the toast and the deletion stuck.
    @ViewBuilder
    private var undoBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "trash.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.AlertRed)

            Text(String.appLocalized("Log Deleted"))
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.PrimaryText)
                .lineLimit(1)

            Spacer(minLength: 12)

            Button {
                transactionVM.undoPendingDelete()
                transactionManager.toDelete = nil
            } label: {
                Text(String.appLocalized("Undo"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.PrimaryText)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.SecondaryBackground, in: Capsule())
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(String.appLocalized("Undo")))
            .accessibilityHint(Text(String.appLocalized("Undo the most recent transaction")))
            .accessibilityIdentifier(AccessibilityID.logUndoButton)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: Capsule())
        .overlay(Capsule().stroke(Color.Outline.opacity(0.5), lineWidth: 0.5))
        .padding(.horizontal, 20)
        .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
    }
}

extension HomeView {

    /// Compact layouts keep the bottom tab strip.
    @ViewBuilder
    private var tabShell: some View {
        TabView(selection: $currentTab) {
                LogView(launchSearch: launchSearch,
                        launchSearchQuery: launchSearchQuery,
                        dayRequest: logDayRequest,
                        showsBookSwitcher: !isWideLayout && !appLockVisible,
                        onAdd: { addTransaction = true })
                    .frame(maxWidth: 760)
                    .frame(maxWidth: .infinity)
                    .tag("Log")
                    .tabItem {
                        Label(String.appLocalized("Log"), systemImage: "list.bullet")
                            .accessibilityIdentifier(AccessibilityID.tabLog)
                    }

                InsightsView(onAdd: { addTransaction = true },
                             onSelectDay: focusLogDay)
                    .frame(maxWidth: 760)
                    .frame(maxWidth: .infinity)
                    .tag("Insights")
                    .tabItem {
                        Label(String.appLocalized("Insights"), systemImage: "chart.bar.fill")
                            .accessibilityIdentifier(AccessibilityID.tabInsights)
                    }

                BudgetView()
                    .frame(maxWidth: 760)
                    .frame(maxWidth: .infinity)
                    .tag("Budget")
                    .tabItem {
                        Label(String.appLocalized("Budget"), systemImage: "chart.pie.fill")
                            .accessibilityIdentifier(AccessibilityID.tabBudget)
                    }

                SettingsView()
                    .frame(maxWidth: 760)
                    .frame(maxWidth: .infinity)
                    .tag("Settings")
                    .tabItem {
                        Label(String.appLocalized("Settings"), systemImage: "gearshape.fill")
                            .accessibilityIdentifier(AccessibilityID.tabSettings)
                    }
        }
    }

    /// Mac always, iPad when it has room; iPhone keeps the tab strip.
    private var isWideLayout: Bool {
        #if os(macOS)
        true
        #else
        horizontalSizeClass == .regular
        #endif
    }

    /// The lock view covers the app; no book picker or sheet from the
    /// previous ledger may remain interactive behind it.
    var appLockVisible: Bool {
        appLockVM.isAppLockEnabled && !appLockVM.isAppUnLocked
    }

    @ViewBuilder
    private var shell: some View {
        Group {
            if isWideLayout {
                // Wide layouts have no bottom tab strip, so the inset belongs
                // to the whole detail column.
                splitShell
                    .safeAreaInset(edge: .bottom, spacing: 0) {
                        if isInFallbackMode {
                            FallbackSyncBanner()
                                .padding(.horizontal, 14)
                                .padding(.bottom, 6)
                        }
                    }
            } else {
                // Compact layouts announce the degraded store once, in
                // ContentView. A persistent strip cannot coexist with the
                // floating tab bar: a bottom inset pushed the bar off-screen
                // and the tab-bar accessory blurs text.
                tabShell
            }
        }
        .environment(transactionManager)
        // Light selection feedback when switching sections (HIG: every
        // interaction gets feedback).
        .sensoryFeedback(.selection, trigger: currentTab)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            AppBackground()

            shell

            if transactionVM.pendingDelete != nil {
                // Bottom snackbar, above the tab bar: the top of the screen
                // is owned by the navigation bar and search field.
                undoBanner
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .padding(.bottom, 100)
                    .padding(.horizontal, SBSpace.medium)
                    .appTransition(.move(edge: .bottom).combined(with: .opacity))
            }

            if appLockVM.isAppLockEnabled && !appLockVM.isAppUnLocked {
                AppLockView()
                    .ignoresSafeArea(.all)
                    .onOpenURL { url in

                        if url.host == "newExpense" {
                            fromURL1 = true
                        } else if url.host == "search" {
                            fromURL2 = true
                        } else if url.host == "insights" {
                            fromURL3 = true
                        } else if url.host == "budget" {
                            fromURL4 = true
                        }
                    }
            }
        }
        .alert(
            deleteDialogTitle,
            isPresented: deleteDialogPresented,
            presenting: transactionManager.toDelete
        ) { transaction in
            Button(String.appLocalized(stopRecurringDelete ? "Confirm" : "Delete"),
                   role: .destructive) {
                transactionManager.showPopup = false
                if stopRecurringDelete {
                    AppMotion.withAnimation(.easeInOut(duration: 0.5)) {
                        transactionVM.stopRecurring(transaction)
                    }
                } else {
                    AppMotion.withAnimation(.easeInOut(duration: 0.5)) {
                        transactionVM.stageDelete(transaction)
                    }
                }
            }
            Button(String.appLocalized("Cancel"), role: .cancel) {
                transactionManager.showPopup = false
                transactionManager.toDelete = nil
            }
        } message: { _ in
            Text(deleteDialogMessage)
        }
        .fullScreenPresentation(item: $transactionManager.toEdit) { transaction in
            TransactionView(toEdit: transaction)
        }
        .sheet(item: $transactionManager.toRefund) { target in
            RefundSheet(target: target)
        }
        .sheet(item: $transactionManager.toBadDebt) { target in
            BadDebtSheet(claim: target.claim)
        }
        .fullScreenPresentation(isPresented: $addTransaction, onDismiss: {
            if confetti && transactionCountBeforeAdd != transactions.count {
                counter += 1
            }
            if firstLaunch {
                firstLaunch = false
            }
        }, content: {
            TransactionView(toEdit: nil)
        })
        .onChange(of: launchAdd) { _, _ in
            requestNewTransaction()
        }
        .onChange(of: addTransaction) { _, isAdding in
            // Snapshot the count when the entry sheet opens so the confetti
            // check on dismiss compares against the right baseline.
            if isAdding { transactionCountBeforeAdd = transactions.count }
        }
        .onOpenURL { url in
            // URL hosts are case-insensitive; `smartbud://newexpense` used to
            // only switch tabs and never open the form.
            if url.host?.lowercased() == "newexpense" {
                requestNewTransaction()
            }
        }
        .onChange(of: appLockVM.isAppUnLocked) { _, unlocked in
            if unlocked {
                guard pendingAddAfterUnlock else { return }
                pendingAddAfterUnlock = false
                addTransaction = true
                return
            }
            closePresentedScreens()
        }
        .onReceive(NotificationCenter.default.publisher(for: .bookDidChange)) { _ in
            // Staged edits, a queued add and the confetti baseline all refer
            // to the ledger that was on screen before the switch.
            closePresentedScreens()
            pendingAddAfterUnlock = false
            transactionManager.toRefund = nil
            transactionManager.toBadDebt = nil
            showConfetti = false
            transactionCountBeforeAdd = transactions.count
        }
        .confettiOverlay(isActive: $showConfetti)
        .onChange(of: counter) { _, _ in showConfetti = true }
        .onAppear {
            #if DEBUG
            if ProcessInfo.processInfo.environment["START_CREATE"] == "1" {
                addTransaction = true
            }
            #endif
            if launchIntoEntry, !appLockVM.isAppLockEnabled {
                addTransaction = true
            }
            if appLockVM.isAppLockEnabled && fromURL1 {
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(500))
                    launchAdd.toggle()
                }

                fromURL1 = false
            }

            if appLockVM.isAppLockEnabled && fromURL2 {
                currentTab = "Log"

                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(500))
                    launchSearch.toggle()
                }

                fromURL2 = false
            }

            if appLockVM.isAppLockEnabled && fromURL3 {
                currentTab = "Insights"
            }

            if appLockVM.isAppLockEnabled && fromURL4 {
                currentTab = "Budget"
            }
        }
        .onOpenURL { url in
            if handleDeepLink(url) { return }

            if url.host == "search" {
                currentTab = "Log"
            } else if url.host == "insights" {
                currentTab = "Insights"
            } else if url.host == "budget" {
                currentTab = "Budget"
            }
        }
        .focusedSceneValue(\.newTransaction, { requestNewTransaction() })
        .focusedSceneValue(\.selectTab, { tab in currentTab = tab })
    }
}
