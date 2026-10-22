//
//  WidgetModelContainer.swift
//  ExpenditureWidget
//
//  Shared SwiftData ModelContainer for all widgets in the extension.
//
//  History: every widget used to declare its own container with `try!`,
//  which can crash the entire widget extension on first launch (or after
//  a schema migration) if the store is locked, the App Group entitlement
//  is missing, or the container URL is unreachable (e.g. dev simulator
//  with stripped signing). Because the extension runs in its own process,
//  that crash takes every widget down.
//
//  This helper centralises the construction and:
//    1. Tries the App-Group-backed configuration first (matches the
//       main app's store at <AppGroup>/MainModel.store so widget
//       timelines see fresh data).
//    2. Probes the App Group container via FileManager; if it isn't
//       reachable, swaps in an in-memory configuration (a known
//       safe degradation that mirrors DataRepository's behaviour on
//       the main-app side).
//    3. Catches any remaining init failure and falls back to an
//       in-memory store, logging via NSLog so it's visible in
//       Console.app. Individual widgets then render empty/placeholder
//       entries rather than bringing the extension down.
//

import Foundation
import SwiftData

enum WidgetModelContainer {
    /// Shared container used by every widget's timeline provider.
    static let shared: ModelContainer = {
        let appGroupID = "group.com.iorest.smartbud"
        let appGroupReachable = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupID
        ) != nil

        let schema = Schema([
            TransactionModel.self,
            CategoryModel.self,
            AccountModel.self,
            TransferModel.self,
            BudgetModel.self,
            MainBudgetModel.self
        ])

        let configurations: [ModelConfiguration]
        if appGroupReachable {
            configurations = [ModelConfiguration(
                "MainModel",
                groupContainer: .identifier(appGroupID)
            )]
        } else {
            NSLog("[WidgetModelContainer] App Group \(appGroupID) not reachable — falling back to in-memory store")
            configurations = [ModelConfiguration(
                "MainModel",
                isStoredInMemoryOnly: true
            )]
        }

        do {
            return try ModelContainer(for: schema, configurations: configurations)
        } catch {
            NSLog("[WidgetModelContainer] ModelContainer init failed: \(error). Falling back to in-memory store.")
            // Last-resort: an in-memory store keeps the extension alive
            // even when the App Group store is unrecoverable.
            do {
                return try ModelContainer(
                    for: schema,
                    configurations: [ModelConfiguration(
                        "MainModel",
                        isStoredInMemoryOnly: true
                    )]
                )
            } catch {
                fatalError("WidgetModelContainer: in-memory fallback also failed: \(error)")
            }
        }
    }()
}
