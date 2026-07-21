//
//  LanguageBundle.swift
//  smartbud
//
//  Bridge between the user's in-app language pick and Foundation's
//  `String(localized:)` / `NSLocalizedString` machinery.
//
//  ## Why this file exists
//
//  SwiftUI's `.environment(\.locale, ...)` only affects SwiftUI's own
//  lookups (`Text("...")` with a `LocalizedStringKey`, `Text(LocalizedStringKey(...))`,
//  format-style `Text("foo \(bar)")`, etc.). It does NOT affect
//  `Foundation.String(localized:)` — those calls go straight to
//  `Bundle.main.localizedString(forKey:value:table:)`, which uses the
//  **process** locale (set by the system, not by the in-app switch).
//
//  The vast majority of the app's UI text is rendered via
//  `Text(String(localized: "..."))`, so without this bridge, switching
//  the language in `Settings → Language` would change the formatters
//  (Locale.appLocale) but leave every visible label in the system
//  language.
//
//  ## How it works
//
//  At process launch, `LanguageBundleInstaller.install()` uses
//  `class_replaceMethod` to swap the `Bundle` class's
//  `localizedString(forKey:value:table:)` method with our override.
//  Every subsequent `Bundle.main.localizedString(...)` call (and every
//  `String(localized:)` which calls through it) dispatches to our
//  override, which loads the `.lproj` for the user-picked language
//  code and looks up the string in *that* bundle.
//
//  The override re-reads `UserDefaults.appGroup` for `appLanguage` on
//  every call, so when the user picks a different language in
//  `SettingsLanguageView` and SwiftUI re-renders the view tree, every
//  `String(localized:)` already returns the new value. No cache
//  invalidation needed.
//
//  The original IMP is stashed on `LanguageBundle.originalIMP` so the
//  override can delegate to the real Foundation localization for the
//  chosen language.
//
//  ## Why not `object_setClass(Bundle.main, ...)`?
//
//  `Bundle.main` is a class cluster instance owned by Foundation;
//  `object_setClass` silently does nothing to those. Method swizzling
//  at the class level (`Bundle.self`) is the standard, supported way
//  to override localization behaviour in iOS apps.
//
//  ## Where it's installed
//
//  - `AppDelegate.application(_:didFinishLaunchingWithOptions:)` — main app.
//  - `SmartBudWidgets.init` — widget extension (separate process, has
//    its own `Bundle` class and its own UserDefaults).
//
//  Both call sites use the same `LanguageBundleInstaller.install()` so
//  the swizzle is identical in both processes.
//

import Foundation
import ObjectiveC
import ObjectiveC.runtime

enum LanguageBundleBridge {
    /// Original IMP of `Bundle.localizedString(forKey:value:table:)`,
    /// captured during `install()`. The override calls this to fall
    /// through to the real Foundation localization for the chosen
    /// language (i.e. the `.lproj/Localizable.strings` file).
    ///
    /// Marked `nonisolated(unsafe)` because the value is written once
    /// at process launch (before any thread can race) and only read
    /// from there on. Mirrors the pattern used by
    /// `UserDefaults.appGroup` in `AppLanguage.swift`.
    nonisolated(unsafe) fileprivate static var originalIMP: IMP?
}

enum LanguageBundleInstaller {
    // `installed` is read/written only at process launch (idempotent
    // first-write-wins), so the relaxed guarantee from
    // `nonisolated(unsafe)` is sufficient.
    nonisolated(unsafe) private static var installed = false

    /// Swizzle `Bundle.localizedString(forKey:value:table:)` with our
    /// language-aware override. Idempotent — safe to call from both
    /// the main app and the widget extension.
    static func install() {
        guard !installed else { return }
        installed = true

        // 1) Look up the original method and capture its IMP.
        guard let originalMethod = class_getInstanceMethod(
            Bundle.self,
            #selector(Bundle.localizedString(forKey:value:table:))
        ) else {
            NSLog("[LanguageBundle] install FAILED: original method not found")
            return
        }
        let originalIMP = method_getImplementation(originalMethod)
        LanguageBundleBridge.originalIMP = originalIMP

        // 2) Build a block that, when called as an IMP, dispatches to
        //    our override. The block's signature mirrors the method
        //    (self, _cmd, key, value, table) -> NSString.
        //
        //    The `obj === Bundle.main` guard restricts in-app language
        //    routing to the main bundle. UIKit 内部私有 NSBundle 子类
        //    (used by `UIMainMenuSystem._defaultRootMenuChildren` and
        //    similar) and `Bundle(path:)` instances created in step (3)
        //    below must keep using Foundation's native lookup; routing
        //    them through `languageAwareLookup` recurses through the
        //    swizzled method with a corrupted receiver and crashes with
        //    EXC_BAD_ACCESS at `objc_retain(0x1)` during the first
        //    CA-commit after launch (regression observed 2026-07-20
        //    on iOS 26.5.1 simulator, fixed 2026-07-20).
        let block: @convention(block) (
            AnyObject, Selector, NSString, NSString?, NSString?
        ) -> NSString = { obj, sel, key, value, table in
            guard obj === Bundle.main else {
                return callOriginal(
                    self: obj, cmd: sel, key: key, value: value, table: table
                )
            }
            return languageAwareLookup(
                self: obj, cmd: sel, key: key, value: value, table: table
            )
        }
        let overrideIMP = imp_implementationWithBlock(block)

        // 3) Replace the original method's IMP with our override.
        //    `class_replaceMethod` returns the *old* IMP, which we
        //    don't need (we already captured it in step 1).
        let originalSelector = #selector(Bundle.localizedString(forKey:value:table:))
        _ = class_replaceMethod(
            Bundle.self,
            originalSelector,
            overrideIMP,
            method_getTypeEncoding(originalMethod)
        )
        NSLog("[LanguageBundle] install: swizzle applied")
    }

    /// The override body. Re-reads `appLanguage` on every call, then
    /// delegates to the stashed original IMP for the chosen language's
    /// `.lproj` bundle.
    private static func languageAwareLookup(
        self: AnyObject,
        cmd: Selector,
        key: NSString,
        value: NSString?,
        table: NSString?
    ) -> NSString {
        // Resolve the user's language pick on every call — no cache.
        // Cheap (one UserDefaults read), and lets a runtime language
        // switch take effect on the very next view re-render.
        let code = UserDefaults.appGroup.string(forKey: AppDefaultsKey.appLanguage) ?? ""
        guard !code.isEmpty else {
            // "Follow system" → behave exactly like the real Bundle.
            return callOriginal(self: self, cmd: cmd, key: key, value: value, table: table)
        }

        // Try the exact identifier first ("zh-Hans", "en", "zh-Hant"),
        // then the language subtag ("zh"), then English, then the
        // system default. Mirrors what iOS does for preferred languages.
        let candidates: [String] = {
            var cs = [code]
            let primary = code.split(separator: "-").first.map(String.init) ?? code
            if primary != code { cs.append(primary) }
            cs.append("en")
            return cs
        }()

        for candidate in candidates {
            if let path = Bundle.main.path(forResource: candidate, ofType: "lproj"),
               let bundle = Bundle(path: path) {
                let result = bundle.localizedString(
                    forKey: key as String,
                    value: value as String?,
                    table: table as String?
                )
                if result != (key as String) { return result as NSString }
            }
        }

        // Nothing matched — defer to the system.
        return callOriginal(self: self, cmd: cmd, key: key, value: value, table: table)
    }

    /// Call the original `Bundle.localizedString` IMP, captured at
    /// `install()` time. Used for "Follow system" and as a final
    /// fallback when no candidate language bundle contains the key.
    private static func callOriginal(
        self: AnyObject,
        cmd: Selector,
        key: NSString,
        value: NSString?,
        table: NSString?
    ) -> NSString {
        guard let imp = LanguageBundleBridge.originalIMP else {
            return key
        }
        typealias Fn = @convention(c) (
            AnyObject, Selector, NSString, NSString?, NSString?
        ) -> NSString
        let fn = unsafeBitCast(imp, to: Fn.self)
        return fn(self, cmd, key, value, table)
    }
}
