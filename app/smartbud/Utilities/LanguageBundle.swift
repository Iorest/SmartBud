//
//  LanguageBundle.swift
//  smartbud
//
//  Historical: Bridge between the user's in-app language pick and
//  Foundation's `String(localized:)` machinery via Bundle method swizzling.
//
//  ## Status: NOT USED
//
//  This file is kept for historical context and to prevent future contributors
//  from re-introducing a Bundle swizzle. The mechanism has been replaced by
//  `String.appLocalized(_:defaultValue:table:bundle:comment:)` in
//  `AppLocale.swift` — see that extension for the new code path.
//
//  ## Why Bundle swizzling was abandoned
//
//  1. **iOS 26 ABI crash (2026-07-20).** Both `imp_implementationWithBlock`
//     + `@convention(block)` and `@convention(c) + unsafeBitCast` paths
//     crashed on the first UIKit call into the swizzled method with
//     `EXC_BAD_ACCESS at objc_retain(0x1)`. The implementation thunk
//     mis-aligns closure-context vs. ObjC-self, so `self` arrives in the
//     wrong register. A `@_cdecl` C-ABI override would dodge this, but…
//
//  2. **String Catalog has no `.lproj`.** `app/smartbud/en.lproj/`,
//     `zh-Hans.lproj/`, `zh-Hant.lproj/` each contain only
//     `InfoPlist.strings`. String Catalog is compiled into a different
//     resource form and the original `Bundle.main.path(forResource: code,
//     ofType: "lproj")` lookup can never find a translation. The original
//     `languageAwareLookup` would have returned the key verbatim even if
//     the swizzle had worked.
//
//  3. **No way to pass the user-picked locale to the override.** Foundation's
//     public `Bundle.localizedString(forKey:value:table:)` reads the
//     process locale internally and does not accept a `Locale` argument.
//     `String(localized:defaultValue:table:bundle:locale:comment:)` does
//     accept one, but its `locale` parameter is honoured only when the
//     target bundle carries a per-locale resource — which String Catalog
//     does not. The cleanest way to actually consume String Catalog with a
//     custom locale is to call that init directly, not through a swizzled
//     `Bundle.localizedString`.
//
//  4. **Recursion.** Any swizzled override that tried to delegate to
//     Foundation via `String(localized:bundle:locale:)` would re-enter the
//     swizzle, requiring a thread-local "in swizzle" flag — at which
//     point the `locale` argument is lost on the second hop.
//
//  ## New approach
//
//  `String.appLocalized(...)` (AppLocale.swift) calls
//  `String(localized:defaultValue:table:bundle:locale:comment:)` with the
//  user-picked `Locale` on every call. It is called from ~300 mechanical
//  replacements of the form `String(localized: "key")` →
//  `String.appLocalized("key")`.
//
//  `AppDelegate.application(_:didFinishLaunchingWithOptions:)` and
//  `ExpenditureWidget.init()` no longer call `install()`.
//

import Foundation

enum LanguageBundleBridge {
    // Empty placeholder kept so any stale reference compiles during the
    // 2026-07-20 transition window. The fields are unused.
}

enum LanguageBundleInstaller {
    /// No-op. The Bundle swizzle is not used — see the file header. Kept
    /// only so that lingering call sites in `AppDelegate` /
    /// `ExpenditureWidget` continue to compile while those files are
    /// updated.
    static func install() {
        // Intentional no-op. See header.
    }
}
