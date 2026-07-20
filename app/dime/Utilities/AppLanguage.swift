//
//  AppLanguage.swift
//  dime
//
//  Single source of truth for the user's in-app language pick.
//
//  Before this file existed, the `appLanguage` key was read in four places,
//  each one declaring its own `@AppStorage("appLanguage", store: ...)` or
//  reaching into the shared `UserDefaults` suite directly. This wrapper
//  centralises the key, the store, and the default ("follow system"),
//  and exposes a typed `Locale?` so the call site at the SwiftUI root
//  becomes a one-liner: `.environment(\.locale, appLanguage.locale ?? Locale.current)`.
//
//  Empty string = "follow system locale". Persisted in the App Group suite
//  so the widget extension could read the same pick in the future.
//

import SwiftUI

extension UserDefaults {
    /// App group store shared with the widget extension.
    /// Falls back to `.standard` when the suite is unavailable
    /// (e.g. unit tests, SwiftUI previews that lack the entitlement).
    nonisolated(unsafe) static let appGroup: UserDefaults = {
        UserDefaults(suiteName: "group.com.rafaelsoh.dime") ?? .standard
    }()
}

enum AppDefaultsKey {
    /// Key for the user's in-app language pick.
    /// Empty string = follow system locale.
    static let appLanguage = "appLanguage"
}

/// SwiftUI property wrapper for the user's in-app language pick.
/// Single source of truth — replaces the four scattered
/// `@AppStorage("appLanguage", store: ...)` declarations across the app.
@propertyWrapper
struct AppLanguage: DynamicProperty {
    @AppStorage(AppDefaultsKey.appLanguage, store: .appGroup)
    private var value: String = ""

    init(wrappedValue: String = "") {
        self._value = AppStorage(wrappedValue: wrappedValue, AppDefaultsKey.appLanguage, store: .appGroup)
    }

    var wrappedValue: String {
        get { value }
        nonmutating set { value = newValue }
    }

    var projectedValue: Binding<String> { $value }
}
