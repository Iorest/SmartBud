import Foundation
import SwiftData
import WidgetKit
import CloudKit
import Observation
import os

private let dataLogger = Logger(subsystem: "com.iorest.smartbud", category: "data")

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

    /// Which store this launch is actually using. Recorded explicitly so the
    /// UI can tell "no iCloud" apart from "nothing will be saved" — they need
    /// very different warnings.
    enum StorageMode: String, Equatable {
        /// App Group + CloudKit: the production path.
        case cloud
        /// App Group, no CloudKit (macOS, or iCloud unavailable this launch).
        case appGroup
        /// On-device store outside the App Group (entitlement missing).
        case device
        /// In-memory only: nothing survives the session.
        case memory
    }

    /// Why the repository ended up in a degraded configuration, if any.
    /// `nil` means the production path (App Group + CloudKit) booted
    /// cleanly.
    private(set) var fallbackReason: FallbackReason?

    private(set) var storageMode: StorageMode = .cloud

    /// `true` when the container is degraded (App-Group-only, local-only,
    /// or in-memory). The UI reads this to show a non-blocking banner
    /// letting the user know their data isn't syncing to iCloud.
    var isInFallbackMode: Bool { fallbackReason != nil }

    /// Nothing written this session will reach disk. The banner has to say
    /// that instead of promising the data will come back later.
    var isEphemeral: Bool { storageMode == .memory }

    /// Last write failure, surfaced by the UI. Writes used to fail silently,
    /// which made every "saved" state a lie when the store was unhealthy.
    private(set) var lastSaveError: String?

    func clearSaveError() {
        lastSaveError = nil
    }

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
        AccountModel.self,
        TransferModel.self,
        CurrencyRate.self,
        BudgetModel.self,
        MainBudgetModel.self,
        TemplateTransactionModel.self
    ])

    init() {
        let built = Self.makeContainer()
        // Staged deletes rely on `rollback()` to restore a row. Autosave would
        // commit the pending delete behind our back (usually before the user
        // taps "Undo"), so persistence must be explicit via `save()`.
        built.container.mainContext.autosaveEnabled = false
        container = built.container
        fallbackReason = built.reason
        storageMode = built.mode
    }

    /// Local-only store: works on simulators and devices without the App
    /// Group entitlement (preview builds, store-less test runs).
    private static func localContainer() -> ModelContainer? {
        try? ModelContainer(
            for: Self.schema,
            configurations: ModelConfiguration(Self.storeName)
        )
    }

    /// Last resort: data won't persist or sync, but the app launches instead
    /// of crashing on a corrupted store. The user sees the fallback banner.
    private static func memoryContainer() -> ModelContainer? {
        try? ModelContainer(
            for: Self.schema,
            configurations: ModelConfiguration(
                Self.storeName,
                isStoredInMemoryOnly: true
            )
        )
    }

    private struct BootResult {
        let container: ModelContainer
        let reason: FallbackReason?
        let mode: StorageMode
    }

    /// Tries App Group + CloudKit, then a local store, then in-memory, so the
    /// app still launches when the preferred store is unavailable.
    private static func makeContainer() -> BootResult {
        var container: ModelContainer!
        var reason: FallbackReason?
        var mode: StorageMode = .cloud

        let appGroupReachable = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: Self.appGroupID
        ) != nil

        // 1. App Group + CloudKit (production path).
        if appGroupReachable {
            #if os(macOS)
            // The macOS target has no iCloud entitlements yet. Configuring
            // CloudKit without them traps inside PFCloudKitContainerProvider
            // (SIGTRAP) on a background queue. Use the App Group store
            // locally until the mac build is team-signed with
            // com.apple.developer.icloud-container-identifiers.
            let cloudConfig: ModelConfiguration? = nil
            #else
            let cloudConfig: ModelConfiguration? = ModelConfiguration(
                Self.storeName,
                groupContainer: .identifier(Self.appGroupID),
                cloudKitDatabase: .private(Self.cloudContainerID)
            )
            #endif

            if let cloudConfig,
               let cloud = try? ModelContainer(for: Self.schema, configurations: cloudConfig) {
                container = cloud
                mode = .cloud
            } else if let fallback = try? ModelContainer(
                for: Self.schema,
                configurations: ModelConfiguration(
                    Self.storeName,
                    groupContainer: .identifier(Self.appGroupID)
                )
            ) {
                // App Group reachable but CloudKit isn't (no iCloud account,
                // iCloud disabled, different Apple ID, or macOS where CloudKit
                // is not wired up yet). The shared store is still the real
                // one, so writes are kept and will sync once iCloud is back.
                container = fallback
                mode = .appGroup
                if cloudConfig != nil { reason = .cloudKitUnavailable }
            } else {
                // App Group is reachable but its store cannot be opened. Do
                // NOT silently create a second, unrelated store elsewhere:
                // anything written there would never be merged back and the
                // user would think their ledger "came back" while the real
                // one sat untouched on disk. Session memory keeps the app
                // usable without touching either store.
                reason = .storageCorrupted
            }
        } else {
            reason = .appGroupUnavailable
        }

        // 2. Without the App Group there is no shared store to protect, so an
        // on-device store is legitimate (entitlement missing, previews).
        if container == nil, !appGroupReachable, let local = Self.localContainer() {
            container = local
            mode = .device
        }

        // 3. In-memory only: data isn't persisted, but nothing is corrupted
        // and no divergent store is created behind the shared one's back.
        if container == nil, let memoryOnly = Self.memoryContainer() {
            container = memoryOnly
            mode = .memory
            reason = .storageCorrupted
        }

        // Even the in-memory init can fail in truly degenerate cases
        // (e.g. schema completely unloadable). At that point the device
        // is in such a bad state that crashing is acceptable — the app
        // has run out of legitimate boot paths.
        guard let container else {
            fatalError("DataRepository: every ModelContainer init attempt failed")
        }
        return BootResult(container: container, reason: reason, mode: mode)
    }

    // MARK: - Convenience accessors

    var context: ModelContext { container.mainContext }
    var modelContainer: ModelContainer { container }

    // MARK: Save

    /// Persists pending changes. Returns `false` (and records
    /// `lastSaveError`) when the store rejects the write.
    @discardableResult
    func save() -> Bool {
        guard context.hasChanges else { return true }
        do {
            try context.save()
            lastSaveError = nil
            WidgetCenter.shared.reloadAllTimelines()
            return true
        } catch {
            // Leave the context exactly as it was on disk. Keeping the failed
            // inserts around made the UI show rows that would vanish on the
            // next launch, and the next successful save would commit them in
            // an order nobody could reason about.
            context.rollback()
            lastSaveError = String.appLocalized("无法保存更改，请稍后重试。")
            dataLogger.error("SwiftData save failed: \(error.localizedDescription, privacy: .public)")
            return false
        }
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

    @discardableResult
    func deleteAll() -> Bool {
        for txn in fetch(TransactionModel.self) { context.delete(txn) }
        for transfer in fetch(TransferModel.self) { context.delete(transfer) }
        for category in fetch(CategoryModel.self) { context.delete(category) }
        for account in fetch(AccountModel.self) { context.delete(account) }
        for rate in fetch(CurrencyRate.self) { context.delete(rate) }
        for budget in fetch(BudgetModel.self) { context.delete(budget) }
        for mainBudget in fetch(MainBudgetModel.self) { context.delete(mainBudget) }
        for tpl in fetch(TemplateTransactionModel.self) { context.delete(tpl) }
        return save()
    }

    // MARK: - CloudKit wipe

    /// Outcome of `wipeEverything()`. Tells the UI whether the local
    /// store and the iCloud zone were both cleared, or only one of them.
    enum WipeOutcome {
        /// Local store cleared and the CloudKit zone deleted (or already gone).
        case complete
        /// Local store cleared; iCloud deletion failed for a transient reason
        /// (network, service unavailable). Re-running the wipe is required —
        /// nothing removes the zone automatically later.
        case iCloudRetryable
        /// Local store cleared, but the signed-in Apple ID has no permission
        /// to delete this zone: almost always a different Apple ID than the
        /// one that owns the data.
        case iCloudAccountMismatch
        /// Local delete itself failed.
        case localFailed
        /// The local store could not be opened at all. Nothing was deleted on
        /// purpose: without a readable local copy the user must not lose the
        /// iCloud backup too.
        case storageUnavailable
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
        // A memory-only session means the real store never opened. Deleting
        // the iCloud zone now would destroy the only copy the user has.
        guard storageMode != .memory else { return .storageUnavailable }

        // 1. Local delete. If the save fails, abort — wiping iCloud when
        //    the local store is in an unknown state is worse than
        //    failing the whole flow.
        guard deleteAll() else { return .localFailed }

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
        } catch let error as CKError {
            switch error.code {
            case .zoneNotFound, .unknownItem:
                // Already gone: the desired end state.
                WidgetCenter.shared.reloadAllTimelines()
                return .complete
            case .notAuthenticated, .permissionFailure:
                return .iCloudAccountMismatch
            default:
                dataLogger.error(
                    "CloudKit zone wipe failed: \(error.localizedDescription, privacy: .public)")
                return .iCloudRetryable
            }
        } catch {
            dataLogger.error(
                "CloudKit zone wipe failed: \(error.localizedDescription, privacy: .public)")
            return .iCloudRetryable
        }
    }
}
