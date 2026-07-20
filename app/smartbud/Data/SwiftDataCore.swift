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
        let config = ModelConfiguration(
            "MainModel",
            groupContainer: .identifier("group.com.rafaelsoh.smartbud"),
            cloudKitDatabase: .private("iCloud.com.rafaelsoh.smartbud")
        )
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
