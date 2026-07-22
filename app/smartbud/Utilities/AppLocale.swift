//
//  AppLocale.swift
//  smartbud
//
//  Bridge between `appLanguage` (UserDefaults) and `Locale` for code that
//  runs outside the SwiftUI view tree and therefore cannot read the
//  `\.locale` environment value.
//
//  `Locale.current` always reflects the **device** locale, which does not
//  change when the user picks a different in-app language in
//  `Settings → Language`. Anywhere the displayed result should honour the
//  in-app switch (currency symbols, decimal separators, currency names,
//  number/date formatters, etc.) use `Locale.appLocale` instead.
//
//  Keep using `Locale.current` for the *device's actual currency*
//  (`Locale.current.currency?.identifier`) — that is not a language concern.
//
//  ## Why child bundles
//
//  `String(localized:defaultValue:table:bundle:locale:comment:)` accepts an
//  explicit `locale:` but in practice resolves through the *bundle's*
//  `preferredLocalizations` array, which is fixed at app launch and
//  dominated by `Locale.current` (the device locale). Passing
//  `Locale(identifier: "en")` does not redirect the lookup. So the only
//  way to get an English string for an in-app language override on iOS 26
//  is to look it up in a *child bundle* rooted at `<app>/en.lproj/`, whose
//  own `preferredLocalizations` is just `["en"]`. The Xcode build emits one
//  `.lproj` directory per locale listed in the String Catalog, so we can
//  resolve them with `Bundle(path: …lproj)` and look up via
//  `Bundle.localizedString(forKey:value:table:)` (or, for
//  `String.LocalizationValue` keys, via the matching
//  `String(localized:bundle:)` overload, which honours the bundle's
//  `preferredLocalizations`).
//

import Foundation

/// Languages with a compiled `.lproj` directory in the app bundle.
private let appSupportedLanguageCodes: [String] = ["en", "zh-Hans", "zh-Hant"]

/// One-time lookup of child `Bundle`s rooted at each `<app>/<code>.lproj`.
/// `nil` entries mean the `.lproj` is missing for that code; the caller
/// should then fall back to the main bundle (which uses the device locale).
private let appChildBundleCache: [String: Bundle] = {
    var result: [String: Bundle] = [:]
    for code in appSupportedLanguageCodes {
        if let path = Bundle.main.path(forResource: code, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            result[code] = bundle
        }
    }
    return result
}()

/// Return the child bundle for the in-app language code, or `nil` if the
/// code is empty (`""` = follow system) or has no compiled `.lproj`.
private func appChildBundle(forLanguageCode code: String) -> Bundle? {
    guard !code.isEmpty else { return nil }
    return appChildBundleCache[code]
}

extension Locale {
    /// The locale the user has selected in `Settings → Language`, falling
    /// back to the device locale when "Follow system" is chosen.
    ///
    /// Reads the same App Group key that SwiftUI view code writes via
    /// `@AppStorage(AppDefaultsKey.appLanguage, store: .appGroup)`. This
    /// accessor is the bridge for non-SwiftUI code paths (formatters,
    /// currency-symbol lookups) that can't read the `\.locale` environment.
    static var appLocale: Locale {
        let code = UserDefaults.appGroup.string(forKey: AppDefaultsKey.appLanguage) ?? ""
        return code.isEmpty ? Locale.current : Locale(identifier: code)
    }

    /// Safe wrapper around `localizedCurrencySymbol(forCurrencyCode:)` that
    /// never returns `nil`. A `Locale` built from an identifier string (the
    /// appLocale case) does not always carry the full ICU currency table,
    /// so we fall back to `Locale.current`, and finally to the raw currency
    /// code itself as a last resort.
    static func appCurrencySymbol(forCurrencyCode code: String) -> String {
        if let s = appLocale.localizedCurrencySymbol(forCurrencyCode: code), !s.isEmpty {
            return s
        }
        if let s = Locale.current.localizedCurrencySymbol(forCurrencyCode: code), !s.isEmpty {
            return s
        }
        return code
    }
}

extension String {
    /// In-app language-aware replacement for `String(localized:)`. Resolves
    /// through the user's `appLanguage` pick (UserDefaults.appGroup), falling
    /// back to the device locale when "Follow system" is chosen.
    ///
    /// Replaces the Bundle swizzle that lived in `LanguageBundle.swift` and
    /// the prior `String(localized:locale:)` form (whose `locale:` argument
    /// is ignored on iOS 26 when the bundle's `preferredLocalizations` is
    /// fixed at launch). Looks up the key in a per-language child bundle so
    /// the result actually matches the user's pick.
    ///
    /// The `key` parameter is `StaticString` so that existing
    /// `String(localized: "key")` call sites — which currently pass a string
    /// literal — keep their zero-cost literal semantics after mechanical
    /// replacement to `String.appLocalized("key")`.
    static func appLocalized(
        _ key: StaticString,
        defaultValue: String.LocalizationValue? = nil,
        table: String? = nil,
        bundle: Bundle? = nil,
        comment: StaticString? = nil
    ) -> String {
        let code = UserDefaults.appGroup.string(forKey: AppDefaultsKey.appLanguage) ?? ""
        let keyString = key.withUTF8Buffer { String(decoding: $0, as: UTF8.self) }
        let target = appChildBundle(forLanguageCode: code) ?? bundle ?? .main
        return target.localizedString(forKey: keyString, value: keyString, table: table)
    }

    /// Overload for `String(appLocalized: "...\(var)...")`-style call sites
    /// that interpolate runtime values into the key. `StaticString` cannot
    /// carry interpolation, so the interpolated form must go through
    /// `String.LocalizationValue`, matching the
    /// `String(localized:String.LocalizationValue, …)` Foundation overload.
    static func appLocalized(
        _ key: String.LocalizationValue,
        table: String? = nil,
        bundle: Bundle? = nil,
        comment: StaticString? = nil
    ) -> String {
        let code = UserDefaults.appGroup.string(forKey: AppDefaultsKey.appLanguage) ?? ""
        let target = appChildBundle(forLanguageCode: code) ?? bundle ?? .main
        let result = String(
            localized: key,
            table: table,
            bundle: target,
            comment: comment
        )
        let keyString = "\(key)"
        if keyString == "Currency" || keyString == "Time Frames" || keyString == "App Icon" || keyString == "Notifications" || keyString == "Theme" {
            NSLog("[appLocalized LV] key=%@ appLanguage=%@ bundle=%@ result=%@", keyString, code, target.bundlePath, result)
        }
        return result
    }
}
