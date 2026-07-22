//
//  SmartBudApp.swift
//  smartbud
//
//  Created by Iorest on 11/7/22.
//

import SwiftUI
import SwiftData
import UIKit

@main
struct SmartBudApp: App {
    @State private var dataRepository = DataRepository.shared
    @State private var appLockVM = AppLockViewModel()
    @State private var tabBarManager = TabBarManager()
    @State private var homeVM = HomeViewModel.shared
    @State private var transactionVM = TransactionViewModel.shared
    @State private var categoryVM = CategoryViewModel.shared
    @State private var budgetVM = BudgetViewModel.shared
    @State private var insightsVM = InsightsViewModel.shared
    @State private var settingsVM = SettingsViewModel.shared

    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        // The app uses a fully custom `TabBar` view instead of SwiftUI's
        // native `TabView`, so hide the system tab bar once at launch
        // (previously this ran inside `HomeView.init`, which fires every
        // time the view was reconstructed).
        UITabBar.appearance().isHidden = true
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(dataRepository.modelContainer)
                .environment(appLockVM)
                .environment(tabBarManager)
                .environment(homeVM)
                .environment(transactionVM)
                .environment(categoryVM)
                .environment(budgetVM)
                .environment(insightsVM)
                .environment(settingsVM)
        }
    }
}
