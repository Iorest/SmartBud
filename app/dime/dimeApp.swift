//
//  dimeApp.swift
//  dime
//
//  Created by Rafael Soh on 11/7/22.
//

import SwiftUI
import SwiftData

@main
struct dimeApp: App {
    @StateObject var dataService: DataService
    @StateObject var unlockManager: UnlockManager
    @StateObject var appLockVM = AppLockViewModel()
    @StateObject var tabBarManager = TabBarManager()
    @StateObject var homeVM: HomeViewModel
    @StateObject var transactionVM: TransactionViewModel
    @StateObject var categoryVM: CategoryViewModel
    @StateObject var budgetVM: BudgetViewModel
    @StateObject var insightsVM: InsightsViewModel
    @StateObject var settingsVM: SettingsViewModel

    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(dataService.modelContainer)
                .environmentObject(dataService)
                .environmentObject(appLockVM)
                .environmentObject(unlockManager)
                .environmentObject(tabBarManager)
                .environmentObject(homeVM)
                .environmentObject(transactionVM)
                .environmentObject(categoryVM)
                .environmentObject(budgetVM)
                .environmentObject(insightsVM)
                .environmentObject(settingsVM)
        }
    }

    init() {
        let dataService = DataService.instance
        let unlockManager = UnlockManager()

        _dataService = StateObject(wrappedValue: dataService)
        _unlockManager = StateObject(wrappedValue: unlockManager)
        _homeVM = StateObject(wrappedValue: HomeViewModel.shared)
        _transactionVM = StateObject(wrappedValue: TransactionViewModel())
        _categoryVM = StateObject(wrappedValue: CategoryViewModel())
        _budgetVM = StateObject(wrappedValue: BudgetViewModel())
        _insightsVM = StateObject(wrappedValue: InsightsViewModel())
        _settingsVM = StateObject(wrappedValue: SettingsViewModel())

        UITableView.appearance().backgroundColor = .clear
    }
}
