//
//  DataRefreshCenter.swift
//  smartbud
//
//  Caches several view models hold their own copy of fetched rows (accounts,
//  categories, budgets, the insights snapshot, rates). Every write path has to
//  refresh them; this is the one place that knows the full list, so import,
//  erase, base-currency switches, CloudKit sync and coming back to the
//  foreground all go through it instead of each fixing a subset.
//

import CloudKit
import CoreData
import Foundation

@MainActor
enum DataRefreshCenter {

    private static var observers: [NSObjectProtocol] = []
    private static var pendingRefresh: Task<Void, Never>?

    /// Starts listening for store changes made by another device. Safe to call
    /// more than once.
    static func start() {
        guard observers.isEmpty else { return }
        let center = NotificationCenter.default

        // SwiftData/CoreData posts this for changes merged from iCloud.
        observers.append(center.addObserver(
            forName: .NSPersistentStoreRemoteChange,
            object: nil,
            queue: .main
        ) { _ in
            scheduleRefresh()
        })

        // CloudKit also reports its own import events; only a finished,
        // successful import means new rows are on disk.
        observers.append(center.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification,
            object: nil,
            queue: .main
        ) { note in
            guard let event = note.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                    as? NSPersistentCloudKitContainer.Event,
                  event.endDate != nil, event.succeeded else { return }
            scheduleRefresh()
        })
    }

    /// Coalesces bursts (CloudKit posts several notifications per import) into
    /// one refresh half a second later.
    private static func scheduleRefresh() {
        pendingRefresh?.cancel()
        pendingRefresh = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            refreshAll()
        }
    }

    /// Rebuilds every cached view of the store.
    static func refreshAll() {
        CurrencyRateStore.shared.load()
        AccountViewModel.shared.load()
        CategoryViewModel.shared.load()
        BudgetViewModel.shared.load()
        InsightsViewModel.shared.refreshAll()
    }
}
