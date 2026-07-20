//
//  ShortcutsProvider.swift
//  smartbud
//
//  Created by Iorest on 5/8/23.
//

import AppIntents
import Foundation

struct SmartBudShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: NewTransactionIntent(),
            phrases: [
                "Log a new transaction in \(.applicationName)"
            ],
            shortTitle: LocalizedStringResource("New Transaction"),
            systemImageName: "books.vertical.fill"
        )
        AppShortcut(
            intent: GetInsightsIntent(),
            phrases: [
                "Get insights in \(.applicationName)"
            ],
            shortTitle: LocalizedStringResource("Get Insights"),
            systemImageName: "plusminus.circle.fill"
        )
        AppShortcut(
            intent: BudgetIntent(),
            phrases: [
                "Extract leftover amount for your budgets in \(.applicationName)"
            ],
            shortTitle: LocalizedStringResource("Extract Budgets"),
            systemImageName: "circle.grid.2x2.fill"
        )
    }
}
