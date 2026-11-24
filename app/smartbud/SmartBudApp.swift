//
//  SmartBudApp.swift
//  smartbud
//
//  Created by Iorest on 11/7/22.
//

import SwiftUI
import SwiftData
import Foundation
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

@main
struct SmartBudApp: App {
    @State private var dataRepository = DataRepository.shared
    @State private var bookState = BookState.shared
    @State private var transactionVM = TransactionViewModel.shared
    @State private var appLockVM = AppLockViewModel()
    @State private var categoryVM = CategoryViewModel.shared
    @State private var accountVM = AccountViewModel.shared
    @State private var rateStore = CurrencyRateStore.shared
    @State private var budgetVM = BudgetViewModel.shared
    @State private var insightsVM = InsightsViewModel.shared
    @State private var settingsVM = SettingsViewModel.shared

    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        CurrencyRateStore.shared.load()
        // Another device's changes should show up without re-entering a screen.
        DataRefreshCenter.start()
        // Tab-bar appearance is now the system default: the app uses the
        // native TabView so iPhone, iPad and Mac (Designed for iPad) share
        // one navigation shell.

        #if DEBUG
        // UI-test seeding (TELE-38). -freshStore gives each launch a fresh
        // SwiftData container, but UserDefaults.appGroup survives a relaunch
        // inside one test run, so these flags pin the settings baseline the
        // C-batch cases assert. They are inert for normal launches.
        let qa = ProcessInfo.processInfo.arguments
        let defaults = UserDefaults.appGroup
        if qa.contains("-qaResetSettings") {
            for key in ["appLanguage", "showNotifications", "notificationOption", "activeIcon"] {
                defaults.removeObject(forKey: key)
            }
        }
        if let index = qa.firstIndex(of: "-qaAppLanguage"), index + 1 < qa.count {
            defaults.set(qa[index + 1], forKey: "appLanguage")
        }
        if qa.contains("-qaNotificationsOn") {
            // Seed before any view mounts so the toggle's onChange (which asks
            // for notification permission) never fires on a CI simulator.
            defaults.set(true, forKey: "showNotifications")
        }
        if qa.contains("-qaSeedRates") {
            // A stored rate makes a base-currency switch show the rebase hint
            // and gives CurrencyRebase.plan an anchor rate to convert with.
            CurrencyRateStore.shared.setRate(1.1, for: "EUR")
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(dataRepository.modelContainer)
                .environment(bookState)
                .environment(transactionVM)
                .environment(appLockVM)
                .environment(categoryVM)
                .environment(accountVM)
                .environment(rateStore)
                .environment(budgetVM)
                .environment(insightsVM)
                .environment(settingsVM)
        }
    }
}
