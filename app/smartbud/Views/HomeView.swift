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
    var showPopup: Bool = false
    var future: Bool = false
}

struct HomeView: View {
    @Environment(AppLockViewModel.self) var appLockVM

    @State var transactionManager = OverallTransactionManager()
    @Environment(TransactionViewModel.self) var transactionVM

    @State var currentTab = "Log"
    var topEdge: CGFloat

    @State var fromURL1: Bool = false
    @State var fromURL2: Bool = false
    @State var fromURL3: Bool = false
    @State var fromURL4: Bool = false

    @State var launchAdd: Bool = false
    @State var launchSearch: Bool = false

    @State var counter = 0
    @State private var showConfetti = false
    var isInFallbackMode: Bool = false

    // Floating add button (replaces the custom tab bar's centre button).
    @State private var addTransaction = false
    @State private var transactionCountBeforeAdd = 0
    @Query private var transactions: [TransactionModel]
    @AppStorage("confetti", store: .appGroup) private var confetti: Bool = false
    @AppStorage("firstTransactionViewLaunch", store: .appGroup) private var firstLaunch: Bool = true

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

    #if os(macOS)
    /// Mac uses a real sidebar instead of the compact tab strip. The detail
    /// column keeps the same 860pt reading width as the iPad layout.
    private var macShell: some View {
        NavigationSplitView {
            List(selection: $currentTab) {
                Label(String.appLocalized("Log"), systemImage: "list.bullet")
                    .tag("Log")
                Label(String.appLocalized("Insights"), systemImage: "chart.bar.fill")
                    .tag("Insights")
                Label(String.appLocalized("Budget"), systemImage: "chart.pie.fill")
                    .tag("Budget")
                Label(String.appLocalized("Settings"), systemImage: "gearshape.fill")
                    .tag("Settings")
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 180, ideal: 210, max: 260)
        } detail: {
            macDetail
        }
                .environment(transactionManager)
    }

    @ViewBuilder
    private var macDetail: some View {
        Group {
            switch currentTab {
            case "Insights":
                InsightsView(onAdd: { addTransaction = true })
            case "Budget":
                BudgetView()
            case "Settings":
                SettingsView()
            default:
                LogView(launchSearch: launchSearch,
                        onAdd: { addTransaction = true })
            }
        }
        .frame(maxWidth: 860)
        .frame(maxWidth: .infinity)
        .background(AppBackground())
        .safeAreaInset(edge: .top, spacing: 0) {
            if isInFallbackMode {
                FallbackSyncBanner()
                    .padding(.horizontal, 14)
                    .padding(.top, 8)
            }
        }
    }
    #endif

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
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: Capsule())
        .overlay(Capsule().stroke(Color.Outline.opacity(0.5), lineWidth: 0.5))
        .padding(.horizontal, 20)
        .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
    }
}

struct AppLockView: View {
    @Environment(AppLockViewModel.self) var appLockVM

    var body: some View {
        VStack(spacing: 15) {
            Image(systemName: "lock.fill")
                .font(.system(size: 65))
                .foregroundStyle(Color.DarkIcon.opacity(0.7))

            Text("App Locked")
                .font(.title.weight(.semibold))
                .foregroundStyle(Color.PrimaryText)
                .padding(.bottom, 30)

            Button {
                appLockVM.appLockValidation()
            } label: {
                HStack {
                    Image(systemName: "faceid")

                    Text("Unlock App")
                }
                .font(.title3.weight(.medium))
                .foregroundStyle(Color.PrimaryText)
                .padding(.horizontal, 40)
                .padding(.vertical, 15)
                .overlay {
                    RoundedRectangle(cornerRadius: SBRadius.card)
                        .stroke(Color.Outline)
                }
            }

            if appLockVM.enrollmentError {
                Text("Please re-enable Face ID access in the Settings app to unlock application.")
                    .font(.subheadline)
                    .foregroundStyle(Color.SubtitleText)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 30)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.PrimaryBackground.opacity(0.3))
        .background(.ultraThinMaterial)
    }
}

extension HomeView {

    var body: some View {
        ZStack(alignment: .bottom) {
            AppBackground()

            #if os(macOS)
            macShell
            #else
            TabView(selection: $currentTab) {
                LogView(launchSearch: launchSearch,
                        onAdd: { addTransaction = true })
                    .frame(maxWidth: 760)
                    .frame(maxWidth: .infinity)
                    .tag("Log")
                    .tabItem {
                        Label(String.appLocalized("Log"), systemImage: "list.bullet")
                    }

                InsightsView(onAdd: { addTransaction = true })
                    .frame(maxWidth: 760)
                    .frame(maxWidth: .infinity)
                    .tag("Insights")
                    .tabItem {
                        Label(String.appLocalized("Insights"), systemImage: "chart.bar.fill")
                    }

                BudgetView()
                    .frame(maxWidth: 760)
                    .frame(maxWidth: .infinity)
                    .tag("Budget")
                    .tabItem {
                        Label(String.appLocalized("Budget"), systemImage: "chart.pie.fill")
                    }

                SettingsView()
                    .frame(maxWidth: 760)
                    .frame(maxWidth: .infinity)
                    .tag("Settings")
                    .tabItem {
                        Label(String.appLocalized("Settings"), systemImage: "gearshape.fill")
                    }
            }
                        .environment(transactionManager)
            // Light selection feedback when switching tabs (HIG: every
            // interaction gets feedback).
            .sensoryFeedback(.selection, trigger: currentTab)
            .overlay(alignment: .top) {
                if isInFallbackMode {
                    FallbackSyncBanner()
                        .padding(.horizontal, 14)
                        .padding(.top, topEdge + 6)
                }
            }
            #endif

            if transactionVM.pendingDelete != nil {
                // Bottom snackbar, above the tab bar: the top of the screen
                // is owned by the navigation bar and search field.
                undoBanner
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .padding(.bottom, 100)
                    .padding(.horizontal, SBSpace.medium)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
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
                    withAnimation(.easeInOut(duration: 0.5)) {
                        transactionVM.stopRecurring(transaction)
                    }
                } else {
                    withAnimation(.easeInOut(duration: 0.5)) {
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
            addTransaction = true
        }
        .onChange(of: addTransaction) { _, isAdding in
            // Snapshot the count when the entry sheet opens so the confetti
            // check on dismiss compares against the right baseline.
            if isAdding { transactionCountBeforeAdd = transactions.count }
        }
        .onOpenURL { url in
            if url.host == "newExpense" {
                addTransaction = true
            }
        }
        .confettiOverlay(isActive: $showConfetti)
        .onChange(of: counter) { _, _ in showConfetti = true }
        .onAppear {
            #if DEBUG
            if ProcessInfo.processInfo.environment["START_CREATE"] == "1" {
                addTransaction = true
            }
            #endif
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
            if url.host == "search" {
                currentTab = "Log"
            } else if url.host == "insights" {
                currentTab = "Insights"
            } else if url.host == "budget" {
                currentTab = "Budget"
            }
        }
    }
}
