//
//  ContentViewModel.swift
//
//  Drives the launch-time bootstrap that used to live in `ContentView`'s
//  60-line `.onAppear`. Also owns the 13 `@AppStorage` values that
//  `ContentView` was reading directly; the view now reads/writes them
//  through this `Observable` object.
//
//  Why this exists:
//    1. `ContentView` had a hard crash on `currency = NSUbiquitousKeyValueStore
//       .default.string(forKey: "currency")!` (old line 97). The currency
//       migration now uses `if let` and falls back to the device locale.
//    2. The first-run defaults, the iCloud currency migration, the update
//       sheet scheduling, and the notification-authorization reconciliation
//       all belong in a view model — they were duplicated between
//       `.onAppear` and `.onChange(of: scenePhase)`.
//    3. `ContentView.body` becomes a thin projection over this VM.
//
//  AppLock is left in `ContentView` because (a) the lock validation
//  needs `AppLockViewModel.isAppUnLocked` to be flipped on the same
//  scene-phase transitions that drive `onAppear` / `onChange`, and
//  (b) keeping it in the view makes the security-relevant code path
//  easy to audit in one place.
//

import SwiftUI
import WidgetKit
import UserNotifications

@MainActor
@Observable
final class ContentViewModel {
    // MARK: - Persisted settings (mirrored to UserDefaults via @AppStorage)

    // `@AppStorage` already observes UserDefaults KVO via its own
    // `DynamicProperty` machinery, so we mark each backing field with
    // `@ObservationIgnored` to stop the `@Observable` macro from
    // re-synthesising `_colourScheme`, `_currency`, etc. Without this,
    // Swift 6 emits "invalid redeclaration of synthesized property"
    // for every `@AppStorage` on an `@Observable` class.
    @ObservationIgnored @AppStorage("colourScheme", store: .appGroup) var colourScheme: Int = 0
    @ObservationIgnored @AppStorage("showNotifications", store: .appGroup) var showNotifications: Bool = false
    @ObservationIgnored @AppStorage("notificationsEnabled", store: .appGroup) var notificationsEnabled: Bool = true
    @ObservationIgnored @AppStorage("firstLaunch", store: .appGroup) var firstLaunch: Bool = true
    @ObservationIgnored @AppStorage("dataMigration1", store: .appGroup) var dataMigration1: Bool = true
    @ObservationIgnored @AppStorage("dataMigration2", store: .appGroup) var dataMigration2: Bool = true
    @ObservationIgnored @AppStorage("currency", store: .appGroup) var currency: String = Locale.current.currency?.identifier ?? "USD"
    @ObservationIgnored @AppStorage("topEdge", store: .appGroup) var savedTopEdge: Double = 30
    @ObservationIgnored @AppStorage("bottomEdge", store: .appGroup) var savedBottomEdge: Double = 15
    @ObservationIgnored @AppStorage("previousVersion", store: .appGroup) var previousVersionString: String = "Version \(UIApplication.appVersion) (\(UIApplication.buildNumber))"
    @ObservationIgnored @AppStorage("showUpdateSheet", store: .appGroup) var showUpdateSheet: Bool = true
    @ObservationIgnored @AppStorage(AppDefaultsKey.appLanguage, store: .appGroup) var appLanguage: String = ""

    // MARK: - Transient presentation state

    var showIntro: Bool = false
    var showUpdate: Bool = false

    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .appGroup) {
        self.defaults = defaults
    }

    // MARK: - Lifecycle

    /// Run once on first view appearance. Replaces the 60-line
    /// `.onAppear` that used to live in `ContentView.body`.
    func bootstrap() {
        if defaults.object(forKey: "firstDayOfMonth") == nil {
            defaults.set(1, forKey: "firstDayOfMonth")
        }

        if firstLaunch {
            showIntro = true
            firstLaunch = false
            showUpdateSheet = false
            dataMigration1 = false
            dataMigration2 = false

            defaults.set(1, forKey: "firstWeekday")
            defaults.set(1, forKey: "haptics")
            defaults.set(1, forKey: "firstDayOfMonth")
            defaults.set(1, forKey: "notificationOption")
            defaults.set(false, forKey: "confetti")
            defaults.set(false, forKey: "chromatic")
            defaults.set(true, forKey: "showCents")
            defaults.set(true, forKey: "animated")
            defaults.set(2, forKey: "numberEntryType")

            seedCurrencyFromICloudIfNeeded()
        } else {
            syncCurrencyFromICloud()
        }

        // SwiftData doesn't need the CoreData-era migrations, but the
        // flags are still touched so older installs see the same default.
        dataMigration1 = false
        dataMigration2 = false

        if showUpdateSheet {
            showUpdate = true
            showUpdateSheet = false
        }

        reconcileNotificationAuthorization()
    }

    /// Persists the safe-area insets measured by the outer `GeometryReader`
    /// so other views (e.g. `HomeView`) can read them back without a
    /// second geometry pass.
    func updateInsets(top: Double, bottom: Double) {
        savedTopEdge = top
        savedBottomEdge = bottom
    }

    /// Called by `ContentView` when the scene transitions back to
    /// `.active`. The old implementation duplicated the same
    /// `getNotificationSettings` block in two places.
    func handleSceneBecameActive() {
        reconcileNotificationAuthorization()
    }

    // MARK: - Private helpers

    /// On first launch, migrate the user's currency pick from
    /// `NSUbiquitousKeyValueStore` so other devices pick it up via iCloud
    /// Key-Value storage. The previous implementation force-unwrapped
    /// `string(forKey:)` (old line 97) which could trap if the value was
    /// ever stored as something other than a `String`.
    private func seedCurrencyFromICloudIfNeeded() {
        let store = NSUbiquitousKeyValueStore.default
        if let stored = store.string(forKey: "currency") {
            currency = stored
        } else {
            let fallback = Locale.current.currency?.identifier ?? "USD"
            store.set(fallback, forKey: "currency")
        }
    }

    /// Subsequent launches: pull any updated currency from iCloud,
    /// seeding the store with the device locale if iCloud doesn't
    /// have one yet.
    private func syncCurrencyFromICloud() {
        let store = NSUbiquitousKeyValueStore.default
        if let stored = store.string(forKey: "currency") {
            currency = stored
        } else {
            let fallback = Locale.current.currency?.identifier ?? "USD"
            currency = fallback
            store.set(fallback, forKey: "currency")
        }
    }

    /// Reconcile `showNotifications` / `notificationsEnabled` against the
    /// current system authorization. Previously duplicated in
    /// `.onAppear` and `.onChange(of: scenePhase)`.
    private func reconcileNotificationAuthorization() {
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            guard let self else { return }
            switch settings.authorizationStatus {
            case .authorized:
                Task { @MainActor in
                    if !self.showNotifications && !self.notificationsEnabled {
                        self.showNotifications = true
                        self.notificationsEnabled = true
                        newNotification()
                    }
                }
            case .denied:
                Task { @MainActor in
                    self.notificationsEnabled = false
                    if self.showNotifications {
                        self.showNotifications = false
                        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
                    }
                }
            default:
                break
            }
        }
    }
}
