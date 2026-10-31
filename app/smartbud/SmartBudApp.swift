//
//  SmartBudApp.swift
//  smartbud
//
//  Created by Iorest on 11/7/22.
//

import SwiftUI
import SwiftData
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

@main
struct SmartBudApp: App {
    @State private var dataRepository = DataRepository.shared
    @State private var appLockVM = AppLockViewModel()
    @State private var transactionVM = TransactionViewModel.shared
    @State private var categoryVM = CategoryViewModel.shared
    @State private var accountVM = AccountViewModel.shared
    @State private var rateStore = CurrencyRateStore.shared
    @State private var budgetVM = BudgetViewModel.shared
    @State private var insightsVM = InsightsViewModel.shared
    @State private var settingsVM = SettingsViewModel.shared

    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        #if DEBUG
        // QA hooks for `SmartBudUITests`, see `UITestFixture`: the store is
        // already in memory (DataRepository), and the App Group defaults are
        // cleared so a case that turns on App Lock or switches the language
        // cannot leak into the next one. Seeding runs before the rate store
        // loads so a seeded foreign currency is usable immediately.
        if UITestFixture.isStoreRequested {
            if !UITestFixture.keepsDefaults {
                UITestFixture.resetDefaults()
            }
            if UITestFixture.isSeedRequested {
                UITestFixture.seed(in: DataRepository.shared.context)
            }
        }
        #endif
        CurrencyRateStore.shared.load()
        // Another device's changes should show up without re-entering a screen.
        DataRefreshCenter.start()
        // Tab-bar appearance is now the system default: the app uses the
        // native TabView so iPhone, iPad and Mac (Designed for iPad) share
        // one navigation shell.
    }

    var body: some Scene {
        WindowGroup {
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
        }
    }
}
