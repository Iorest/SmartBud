//
//  SmartBudMacApp.swift
//  SmartBud-macOS
//
//  Native macOS entry point. Shares the SwiftData container, view models and
//  every screen with the iOS app; only the window chrome and the navigation
//  shell differ (see `HomeView`'s macOS branch).
//

import SwiftUI
import SwiftData

@main
struct SmartBudMacApp: App {
    @State private var dataRepository = DataRepository.shared
    @State private var appLockVM = AppLockViewModel()
    @State private var transactionVM = TransactionViewModel.shared
    @State private var categoryVM = CategoryViewModel.shared
    @State private var accountVM = AccountViewModel.shared
    @State private var rateStore = CurrencyRateStore.shared
    @State private var budgetVM = BudgetViewModel.shared
    @State private var insightsVM = InsightsViewModel.shared
    @State private var settingsVM = SettingsViewModel.shared

    init() {
        CurrencyRateStore.shared.load()
    }

    var body: some Scene {
        // A single, restorable window. `WindowGroup` can end up with no
        // window at all after the user closes it (and with the New Item
        // command removed there is no way to make another one), which
        // looks exactly like a crash.
        Window("SmartBud", id: "main") {
            ContentView()
                .modelContainer(dataRepository.modelContainer)
                .environment(appLockVM)
                .environment(transactionVM)
                .environment(categoryVM)
                .environment(accountVM)
                .environment(rateStore)
                .environment(budgetVM)
                .environment(insightsVM)
                .environment(settingsVM)
                .frame(minWidth: 960, minHeight: 640)
        }
        .commands { SmartBudCommands() }
        .defaultSize(width: 1180, height: 780)
        .windowResizability(.contentMinSize)
    }
}
