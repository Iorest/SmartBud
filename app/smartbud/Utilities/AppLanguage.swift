// `UserDefaults.appGroup` and `AppDefaultsKey.appLanguage` below are the
// single source of truth for the in-app language key + App Group store.
// They are read directly by:
//   - `String.appLocalized(...)` and `Locale.appLocale` in `AppLocale.swift`
//   - `@AppStorage(AppDefaultsKey.appLanguage, store: .appGroup)` at the
//     call sites that need to participate in SwiftUI's automatic
//     re-render on UserDefaults change (ContentView, SettingsView,
//     SettingsLanguageView).
//
// A previous `@AppLanguage` `DynamicProperty` wrapper lived in this file.
// It was removed because the wrapper never forwarded `update()` to its
// internal `@AppStorage`, so views using it (e.g. LogView) did not
// re-render when the user picked a new language in Settings and the
// LogView kept showing strings resolved for the old `appLanguage` value
// until the app was relaunched. SwiftUI's built-in `@AppStorage` is
// itself a `DynamicProperty` and observes UserDefaults KVO directly, so
// using it at the call site removes the indirection entirely.

import Foundation

extension UserDefaults {
    /// App group store shared with the widget extension.
    /// Falls back to `.standard` when the suite is unavailable
    /// (e.g. unit tests, SwiftUI previews that lack the entitlement).
    nonisolated(unsafe) static let appGroup: UserDefaults = {
        UserDefaults(suiteName: "group.com.iorest.smartbud") ?? .standard
    }()
}

enum AppDefaultsKey {
    /// Key for the user's in-app language pick.
    /// Empty string = follow system locale.
    static let appLanguage = "appLanguage"
}
