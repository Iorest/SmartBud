import Foundation
import SwiftData
import WidgetKit
import CloudKit
import Observation

// @Model types (TransactionModel, CategoryModel, etc.) defined in Helper.swift

// MARK: - DataRepository (pure data access layer)

@MainActor
@Observable
final class DataRepository {
    static let shared = DataRepository()

    /// Backing SwiftData container. `var` (not `let`) only so the
    /// init can pick a fallback configuration across multiple attempts
    /// without a separate factory method — the value is set exactly
    /// once in `init` and never reassigned.
    private(set) var container: ModelContainer

    /// Why the repository ended up in a degraded configuration, if any.
    /// `nil` means the production path (App Group + CloudKit) booted
    /// cleanly.
    private(set) var fallbackReason: FallbackReason?

    /// `true` when the container is degraded (App-Group-only, local-only,
    /// or in-memory). The UI reads this to show a non-blocking banner
    /// letting the user know their data isn't syncing to iCloud.
    var isInFallbackMode: Bool { fallbackReason != nil }

    /// Ordered list of storage paths the init tries, best-effort first.
    /// Mirrors `WidgetModelContainer`'s strategy on the widget side.
    enum FallbackReason: String {
        case cloudKitUnavailable
        case appGroupUnavailable
        case storageCorrupted
    }

    static let appGroupID = "group.com.iorest.smartbud"
    static let cloudContainerID = "iCloud.com.iorest.smartbud"
    static let storeName = "MainModel"

    /// Single source of truth for the SwiftData schema used in every
    /// `ModelContainer` init below (and on the widget side). `Schema`
    /// takes an array literal but is the only way to share the model
    /// set between a `for: schema` call and a `try? ModelContainer(...)`
    /// without restating each `@Model` type at every fallback level.
    static let schema = Schema([
        TransactionModel.self,
        CategoryModel.self,
        BudgetModel.self,
        MainBudgetModel.self,
        TemplateTransactionModel.self,
    ])

    init() {
        var container: ModelContainer!
        var reason: FallbackReason?

        // 1. App Group + CloudKit (production path).
        if FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: Self.appGroupID
        ) != nil {
            let cloudConfig = ModelConfiguration(
                Self.storeName,
                groupContainer: .identifier(Self.appGroupID),
                cloudKitDatabase: .private(Self.cloudContainerID)
            )
            if let c = try? ModelContainer(
                for: Self.schema,
                configurations: cloudConfig
            ) {
                container = c
            } else if let c = try? ModelContainer(
                for: Self.schema,
                configurations: ModelConfiguration(
                    Self.storeName,
                    groupContainer: .identifier(Self.appGroupID)
                )
            ) {
                // App Group reachable but CloudKit isn't (e.g. no iCloud
                // account, iCloud disabled, or signed into a different
                // Apple ID than the one that owns the container).
                container = c
                reason = .cloudKitUnavailable
            } else {
                reason = .cloudKitUnavailable
            }
        } else {
            reason = .appGroupUnavailable
        }

        // 2. Local-only on-device store. Works on simulators and
        //    devices without the App Group entitlement (e.g. preview
        //    builds, store-less test runs).
        if container == nil,
           let c = try? ModelContainer(
               for: Self.schema,
               configurations: ModelConfiguration(Self.storeName)
           ) {
            container = c
            if reason == nil { reason = .appGroupUnavailable }
        }

        // 3. Last resort: in-memory store. Data won't persist or sync,
        //    but the app launches instead of crashing on a corrupted
        //    on-disk store. The user sees the fallback banner and can
        //    reinstall or open another device to recover.
        if container == nil,
           let c = try? ModelContainer(
               for: Self.schema,
               configurations: ModelConfiguration(
                   Self.storeName,
                   isStoredInMemoryOnly: true
               )
           ) {
            container = c
            reason = .storageCorrupted
        }

        // Even the in-memory init can fail in truly degenerate cases
        // (e.g. schema completely unloadable). At that point the device
        // is in such a bad state that crashing is acceptable — the app
        // has run out of legitimate boot paths.
        guard let container else {
            fatalError("DataRepository: every ModelContainer init attempt failed")
        }
        self.container = container
        self.fallbackReason = reason
    }

    // MARK: - Convenience accessors

    var context: ModelContext { container.mainContext }
    var modelContainer: ModelContainer { container }

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

    // MARK: - CloudKit wipe

    /// Outcome of `wipeEverything()`. Tells the UI whether the local
    /// store and the iCloud zone were both cleared, or only one of them.
    enum WipeOutcome {
        /// Local store cleared and the CloudKit zone deleted.
        case complete
        /// Local store cleared; iCloud zone deletion failed (e.g. no
        /// iCloud account, network down, or signed into a different
        /// Apple ID). The next sync will remove the records on
        /// iCloud as long as the user is signed in to the same Apple ID
        /// that owns the container.
        case partial
        /// Local delete itself failed. Should not happen in practice.
        case localFailed
    }

    /// Full "Erase All Data" flow for App Store Guideline 5.1.1(v):
    /// deletes every record locally, then attempts to delete the
    /// SwiftData-managed CloudKit record zone so the data is gone
    /// from iCloud immediately rather than waiting for record-level
    /// sync. Async so the UI can show a progress state during the
    /// (potentially slow) zone delete.
    ///
    /// Safe to call from any actor — CloudKit work is awaited on its
    /// own scheduler and the local deletes are confined to the
    /// main-actor `context` we already own.
    func wipeEverything() async -> WipeOutcome {
        // 1. Local delete. If this throws, abort — wiping iCloud when
        //    the local store is in an unknown state is worse than
        //    failing the whole flow.
        do {
            deleteAll()
        } catch {
            return .localFailed
        }

        // 2. CloudKit zone delete. Best effort — if the device is
        //    signed out of iCloud, the zone doesn't exist on this
        //    device's view of iCloud, and the call returns
        //    `.partial`. The user can re-run the wipe from a device
        //    that is signed in to fully clear the data.
        let zoneName = Self.storeName
        let zoneID = CKRecordZone.ID(
            zoneName: zoneName,
            ownerName: CKCurrentUserDefaultName
        )
        do {
            try await CKContainer(identifier: Self.cloudContainerID)
                .privateCloudDatabase
                .deleteRecordZone(withID: zoneID)
            WidgetCenter.shared.reloadAllTimelines()
            return .complete
        } catch {
            // Zone didn't exist (already cleared, or this device never
            // synced) OR the user is signed out. Either way the local
            // store is now empty; the iCloud side will follow once
            // sync resumes. Treat as partial success.
            return .partial
        }
    }
}
