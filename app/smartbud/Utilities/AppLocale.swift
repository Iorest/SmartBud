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
//  ## Why explicit `localizations:` on Bundle.main
//
//  An earlier design used `Bundle(path: "<app>/en.lproj")` as a "child
//  bundle" for in-app English lookups, and an even earlier one swizzled
//  the main bundle's `localizedString(forKey:value:table:)` (iOS 26 ABI
//  crash 2026-07-20). Both were wrong: a child bundle built from an
//  `.lproj` directory has no `Info.plist`, so its `localizations` is
//  empty and its lookup falls back to the parent main bundle's
//  `preferredLocalizations`, which is dominated by the **device** locale
//  (e.g. zh-Hans). Result: in-app English still resolved to the device's
//  Chinese translations — the same bug now reproduced on iOS 26.5.
//
//  `String(localized:locale:)` has the same problem: the `locale:` arg
//  is honoured only when it can be satisfied by the receiver bundle's
//  `localizations` list, and that list on a child `.lproj` bundle is
//  effectively "follow the device's preferredLocalizations".
//
//  The working pattern is to call
//  `Bundle.main.localizedString(forKey:value:table:localizations:)` with
//  an explicit list of preferred language codes:
//    1. the in-app pick (e.g. `"en"` or `"zh-Hans"`),
//    2. the source language (`"en"`) as a safety net for source keys,
//    3. the device's `preferredLocalizations` for any key only present
//       in some other locale (e.g. zh-Hant on a zh-Hans device).
//  Foundation's localization engine picks the first match against the
//  main bundle's `localizations = ["zh-Hans", "en", "Base", "zh-Hant"]`,
//  so passing `["en", "zh-Hans", ...]` is enough to force English
//  regardless of device locale.
//

import Foundation

/// Languages the in-app language picker can set `appLanguage` to. The
/// empty string `""` means "follow system locale".
private let appLanguageCodeCandidates: [String] = ["", "en", "zh-Hans", "zh-Hant"]

/// Resolves the active in-app language code. An unknown value (e.g.
/// a stale entry from a previous app version) is normalised to `""`
/// (Follow system) rather than passed through.
private func resolvedAppLanguageCode() -> String {
    let raw = UserDefaults.appGroup.string(forKey: AppDefaultsKey.appLanguage) ?? ""
    return appLanguageCodeCandidates.contains(raw) ? raw : ""
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
        let code = resolvedAppLanguageCode()
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

/// Builds the ordered list of `Locale.Language` values that the
/// `Bundle.main.localizedString(...localizations:)` API uses to pick
/// which `.lproj` to read from.
///
/// Order matters: Foundation picks the first localization in this list
/// that is present in the main bundle's `localizations` array. So the
/// in-app language is always tried first, then the source language
/// (`en`) as a safety net, then the device's preferred localizations so
/// that a zh-Hant user on a zh-Hans device still finds zh-Hant strings
/// for any key that hasn't been translated into the in-app language.
private func appLookupLanguages(forAppLanguageCode code: String) -> [Locale.Language] {
    let devicePreferred = Bundle.main.preferredLocalizations.map { Locale.Language(identifier: $0) }
    if code.isEmpty {
        // Follow system: device preferred only, in the order the user
        // configured on the device.
        return devicePreferred
    }
    // Explicit in-app language: user pick first, then en, then device
    // preferred (deduped, source en kept in the middle as a safety net).
    var langs: [Locale.Language] = [Locale.Language(identifier: code), Locale.Language(identifier: "en")]
    for lang in devicePreferred where !langs.contains(lang) {
        langs.append(lang)
    }
    return langs
}

extension String {
    /// In-app language-aware replacement for `String(localized:)`. Resolves
    /// through the user's `appLanguage` pick (UserDefaults.appGroup), falling
    /// back to the device locale when "Follow system" is chosen.
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
        let keyString = key.withUTF8Buffer { String(decoding: $0, as: UTF8.self) }
        let code = resolvedAppLanguageCode()
        let target = bundle ?? .main
        let languages = appLookupLanguages(forAppLanguageCode: code)
        return target.localizedString(forKey: keyString, value: keyString, table: table, localizations: languages)
    }

    /// Overload for runtime String keys (e.g. `SettingsKey.rowCurrency`).
    /// `StaticString` can't be created from a non-literal, so call sites
    /// that pass a String constant need this entry point. The implementation
    /// is identical to the StaticString overload — the StaticString
    /// parameter only exists to keep zero-cost literal semantics at
    /// `String.appLocalized("literal")` sites.
    static func appLocalized(
        _ key: String,
        table: String? = nil,
        bundle: Bundle? = nil
    ) -> String {
        let code = resolvedAppLanguageCode()
        let target = bundle ?? .main
        let languages = appLookupLanguages(forAppLanguageCode: code)
        return target.localizedString(forKey: key, value: key, table: table, localizations: languages)
    }

    /// Localizes a format template and substitutes arguments. Use this for
    /// interpolated strings: `String(localized:)` follows the device locale,
    /// not the in-app language pick, and `String.appLocalized` cannot carry
    /// format arguments.
    static func appFormatted(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: appLocalized(key), arguments: arguments)
    }

    /// Overload for `String(appLocalized: "...\(var)...")`-style call sites
    /// that wrap a String in `String.LocalizationValue`. Kept for parity
    /// with the original Foundation-style API; current call sites all
    /// pass plain Strings via the overload above. Uses `Mirror` to extract
    /// the underlying string, because `String.LocalizationValue` does not
    /// expose its storage as a public `value` property in this Swift
    /// version and `"\(key)"` returns the struct's debug description
    /// (e.g. `"LocalizationValue(arguments: [])"`).
    static func appLocalized(
        _ key: String.LocalizationValue,
        table: String? = nil,
        bundle: Bundle? = nil,
        comment: StaticString? = nil
    ) -> String {
        // Swift 6 stores the literal in a `key` child (older builds used
        // `value`/`_value`); missing every label returned "" and the UI
        // silently dropped the whole Text.
        let keyString = Mirror(reflecting: key).children
            .first(where: { $0.label == "value" || $0.label == "_value" || $0.label == "key" })
            .map { "\($0.value)" } ?? ""
        let code = resolvedAppLanguageCode()
        let target = bundle ?? .main
        let languages = appLookupLanguages(forAppLanguageCode: code)
        return target.localizedString(forKey: keyString, value: keyString, table: table, localizations: languages)
    }
}
