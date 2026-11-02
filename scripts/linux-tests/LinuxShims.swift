// Test-harness-only shims. Never ships in the app.
//
// `AppLocale.swift` and `AppLanguage.swift` are excluded from the Linux build:
// swift-corelibs Foundation has neither `String.LocalizationValue` nor
// `localizedString(forKey:value:table:localizations:)`, so those two files only
// compile against Apple's Foundation.
//
// The logic layer only needs three symbols from them, reproduced here from the
// same App Group key so ledger / budget / validation / parsing-adjacent code can
// be exercised on Linux while GitHub's macOS runners are unavailable.
//
// Consequence, stated plainly: anything that depends on the in-app language
// override or on ICU currency symbols is NOT covered by this harness. Those
// assertions stay with the macOS test job.

import Foundation

#if !canImport(Darwin)

extension UserDefaults {
    static var appGroup: UserDefaults {
        UserDefaults(suiteName: "group.com.smartbud.app") ?? .standard
    }
}

extension Locale {
    static var appLocale: Locale {
        let code = UserDefaults.appGroup.string(forKey: "appLanguage") ?? ""
        return code.isEmpty || code == "system" ? Locale.current : Locale(identifier: code)
    }

    static func appCurrencySymbol(forCurrencyCode code: String) -> String {
        if let symbol = appLocale.localizedCurrencySymbol(forCurrencyCode: code), !symbol.isEmpty {
            return symbol
        }
        if let symbol = Locale.current.localizedCurrencySymbol(forCurrencyCode: code), !symbol.isEmpty {
            return symbol
        }
        return code
    }
}

#endif
