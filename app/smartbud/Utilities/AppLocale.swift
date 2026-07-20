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

import Foundation

extension Locale {
    /// The locale the user has selected in `Settings → Language`, falling
    /// back to the device locale when "Follow system" is chosen.
    ///
    /// Reads the same App Group key that the SwiftUI `@AppLanguage`
    /// property wrapper writes. SwiftUI view code should prefer
    /// `@AppLanguage var appLanguage` and `appLanguage.locale`; this
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
