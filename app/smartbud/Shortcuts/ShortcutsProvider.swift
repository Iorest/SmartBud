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
        // iOS 26.5 simulator's `tccd` does not respond to the
        // `kTCCServiceLiverpool` request that AppShortcutsProvider
        // fires on first call, hanging the main thread synchronously
        // and presenting as a black screen (regression 2026-07-20).
        // Skip registration on simulator builds so the app at least
        // launches; device builds keep the full Siri Suggestions
        // integration. The build-time `appintentsmetadataprocessor`
        // pass still runs (this is a runtime check, not a compile
        // one) and produces the same Metadata.appintents artifact.
        #if targetEnvironment(simulator)
        return []
        #else
        return [
            AppShortcut(
                intent: NewTransactionIntent(),
                phrases: [
                    "Log a new transaction in \(.applicationName)"
                ],
                shortTitle: LocalizedStringResource("New Transaction"),
                systemImageName: "books.vertical.fill"
            ),
            AppShortcut(
                intent: GetInsightsIntent(),
                phrases: [
                    "Get insights in \(.applicationName)"
                ],
                shortTitle: LocalizedStringResource("Get Insights"),
                systemImageName: "plusminus.circle.fill"
            ),
            AppShortcut(
                intent: BudgetIntent(),
                phrases: [
                    "Extract leftover amount for your budgets in \(.applicationName)"
                ],
                shortTitle: LocalizedStringResource("Extract Budgets"),
                systemImageName: "circle.grid.2x2.fill"
            )
        ]
        #endif
    }
}
