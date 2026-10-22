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
    @State private var budgetVM = BudgetViewModel.shared
    @State private var insightsVM = InsightsViewModel.shared
    @State private var settingsVM = SettingsViewModel.shared

    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
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
                .environment(budgetVM)
                .environment(insightsVM)
                .environment(settingsVM)
        }
    }
}
