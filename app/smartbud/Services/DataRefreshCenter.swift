//
//  DataRefreshCenter.swift
//  smartbud
//
//  Caches several view models hold their own copy of fetched rows (accounts,
//  categories, budgets, the insights snapshot, rates). Every write path has to
//  refresh them; this is the one place that knows the full list, so import,
//  erase, base-currency switches, CloudKit sync and coming back to the
//  foreground all go through it instead of each fixing a subset.
import CloudKit
import CoreData
import Foundation
import OSLog
import Observation
import WidgetKit

private let syncLogger = Logger(subsystem: "com.iorest.smartbud", category: "sync")

extension Notification.Name {
    /// Posted after the active book changes. Views use it to drop transient
    /// state (open sheets, search text, batch selection) that belongs to the
    /// book they were looking at before the switch.
    static let bookDidChange = Notification.Name("bookDidChange")
}

/// The one observable source of "which book am I looking at". Widgets live in
/// another process and read `BookSelection` from the App Group defaults
/// directly; every screen and view model in the app reads this instance.
@MainActor
@Observable
final class BookState {
    static let shared = BookState()

    private(set) var currentID: UUID
    private(set) var availableBooks: [BookModel] = []

    private init() {
        currentID = BookSelection.current()
    }

    var currentName: String {
        availableBooks.first { $0.id == currentID }?.name ?? BookModel.defaultName
    }

    func isCurrent(_ bookID: UUID?) -> Bool {
        BookScope.matches(bookID, selected: currentID)
    }

    /// Rebuilds the switcher list and repairs a stale selection (e.g. a book
    /// removed by a restore) before any screen reads it.
    func reloadBooks() {
        let all = DataRepository.shared.fetch(BookModel.self)
        availableBooks = all.sorted {
            if $0.archived != $1.archived { return !$0.archived }
            if $0.order != $1.order { return $0.order < $1.order }
            return $0.dateCreated < $1.dateCreated
        }
        if !all.contains(where: { $0.id == currentID }) {
            currentID = BookModel.defaultID
            BookSelection.select(currentID)
        }
    }

    /// Switches book, clears every cached view of the old one, and asks the
    /// widget to re-render. A selection that is not among the known books is
    /// rejected so a stale deep link cannot silently create an "empty" book.
    @discardableResult
    func select(_ id: UUID) -> Bool {
        // A cold launch with a deep link can reach here before bootstrap has
        // loaded the book list; refresh from the store instead of silently
        // ignoring a valid selection.
        if !availableBooks.contains(where: { $0.id == id }) { reloadBooks() }
        guard availableBooks.contains(where: { $0.id == id }), id != currentID else { return false }
        BookSelection.select(id)
        currentID = id
        TransactionViewModel.shared.discardPendingDelete()
        DataRefreshCenter.refreshAll()
        WidgetCenter.shared.reloadAllTimelines()
        NotificationCenter.default.post(name: .bookDidChange, object: self)
        return true
    }
}

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
                  event.endDate != nil else { return }
            guard event.succeeded else {
                // A failed import used to be dropped entirely: the app looked
                // in sync while another device's changes never arrived.
                syncLogger.error(
                    "CloudKit sync failed: \(event.error?.localizedDescription ?? "unknown", privacy: .public)")
                return
            }
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
        BookState.shared.reloadBooks()
        CurrencyRateStore.shared.load()
        AccountViewModel.shared.load()
        CategoryViewModel.shared.load()
        BudgetViewModel.shared.load()
        InsightsViewModel.shared.refreshAll()
    }
}
