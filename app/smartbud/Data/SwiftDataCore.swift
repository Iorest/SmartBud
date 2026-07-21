import Foundation
import SwiftData
import WidgetKit
import Observation

// @Model types (TransactionModel, CategoryModel, etc.) defined in Helper.swift

// MARK: - DataRepository (pure data access layer)

@MainActor
@Observable
final class DataRepository{
    static let shared = DataRepository()

    let container: ModelContainer
    var context: ModelContext { container.mainContext }
    var modelContainer: ModelContainer { container }

    init() {
        // Aligned with widget extensions: they all read via
        // `ModelConfiguration("MainModel", groupContainer: .identifier(...))`,
        // which resolves to `<AppGroup>/MainModel.store`. Using the same
        // `name:` + `groupContainer:` initializer here keeps both targets
        // pointing at the same SQLite file, so `WidgetCenter.reloadAllTimelines()`
        // refreshes actually show the latest data.
        //
        // CloudKit private-database sync is enabled on the main-app side only;
        // the widget intentionally omits `cloudKitDatabase:` and just reads
        // the locally-synced file.
        //
        // Defensive fallback: if the App Group container isn't reachable
        // (e.g. running in a simulator with stripped signing/entitlements),
        // SwiftData's `ModelConfiguration(groupContainer:)` will trap with
        // a fatal "Unable to find App Group Container" error. Probe the
        // container with `FileManager` first; if it's nil, fall back to a
        // local-only `ModelConfiguration` so the app at least launches.
        // The widget and main app will then have separate stores — that's
        // an acceptable dev-simulator degradation; production builds with
        // proper signing always take the App Group path.
        let appGroupID = "group.com.iorest.smartbud"
        let useAppGroup = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupID
        ) != nil

        let config: ModelConfiguration
        if useAppGroup {
            config = ModelConfiguration(
                "MainModel",
                groupContainer: .identifier(appGroupID),
                cloudKitDatabase: .private("iCloud.com.iorest.smartbud")
            )
        } else {
            // Local-only store. No group container, no CloudKit — both
            // can hang `ModelContainer` init on iOS 26.5.1 simulator
            // when the App Group / iCloud account is unreachable, which
            // presents as a black screen on first launch (regression
            // 2026-07-20). The widget and main app will then have
            // separate stores; that's an acceptable dev-simulator
            // degradation. Production builds with proper signing
            // always take the App Group + CloudKit path above.
            config = ModelConfiguration("MainModel")
        }
        do {
            container = try ModelContainer(
                for: TransactionModel.self, CategoryModel.self,
                BudgetModel.self, MainBudgetModel.self, TemplateTransactionModel.self,
                configurations: config
            )
        } catch {
            fatalError("ModelContainer failed: \(error)")
        }
    }

    // MARK: Save

    func save() {
        guard context.hasChanges else { return }
        try? context.save()
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Discards any uncommitted (unsaved) inserts/deletes/updates in the context.
    /// Used to support "undo" on staged deletes before they are saved.
    func rollback() {
        context.rollback()
    }

    // MARK: Insert / Delete

    func insert(_ object: any PersistentModel) {
        context.insert(object)
    }

    func delete(_ object: any PersistentModel) {
        context.delete(object)
    }

    // MARK: Fetch

    func fetch<T: PersistentModel>(
        _ type: T.Type,
        predicate: Predicate<T>? = nil,
        sort: [SortDescriptor<T>] = []
    ) -> [T] {
        let descriptor = FetchDescriptor<T>(predicate: predicate, sortBy: sort)
        return (try? context.fetch(descriptor)) ?? []
    }

    func fetchOne<T: PersistentModel>(
        _ type: T.Type,
        predicate: Predicate<T>
    ) -> T? {
        var descriptor = FetchDescriptor<T>(predicate: predicate)
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    // MARK: Bulk Delete

    func deleteAll() {
        for t in fetch(TransactionModel.self) { context.delete(t) }
        for c in fetch(CategoryModel.self) { context.delete(c) }
        for b in fetch(BudgetModel.self) { context.delete(b) }
        for m in fetch(MainBudgetModel.self) { context.delete(m) }
        try? context.save()
        WidgetCenter.shared.reloadAllTimelines()
    }
}
