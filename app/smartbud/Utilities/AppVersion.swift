//
//  AppVersion.swift
//  smartbud
//
//  Single source of truth for the app's display name, version, and
//  build number. All values read from `Bundle.main.infoDictionary` and
//  fall back to a human-readable string if the key is missing or the
//  value isn't a `String`. Centralising the lookups here means:
//    * Callers never have to write `?? "fallback"` themselves.
//    * If a future build system changes which Info.plist key
//      carries the version, only this file needs to be updated.
//    * The Optional vs non-Optional question is settled: version
//      and build are non-Optional with a sensible default, so
//      `\(appVersion)` interpolations never produce a missing-value
//      string like `"Version "`.
//

import Foundation
import UIKit

// MARK: - Bundle (non-Optional, with "Could not determine …" fallback)

extension Bundle {
    /// App display name. Maps to the `CFBundleDisplayName` key in
    /// Info.plist (set via the `InfoPlist.strings` catalog for each
    /// supported language — en / zh-Hans / zh-Hant).
    var displayName: String {
        object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? "SmartBud"
    }

    /// Build number (e.g. `42`). Maps to `CFBundleVersion`, which is
    /// the `CURRENT_PROJECT_VERSION` Xcode build setting.
    var appBuild: String {
        object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
    }

    /// Marketing version (e.g. `2.1.4`). Maps to `CFBundleShortVersionString`,
    /// which is the `MARKETING_VERSION` Xcode build setting.
    var appVersion: String {
        object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
    }
}

// MARK: - UIApplication (computed delegates, kept for call-site ergonomics)

extension UIApplication {
    /// Same as `Bundle.main.appVersion`. Kept for existing call sites
    /// that already read it through `UIApplication.appVersion`; the
    /// single source of truth lives on `Bundle`.
    static var appVersion: String { Bundle.main.appVersion }

    /// Same as `Bundle.main.appBuild`. See `appVersion` above.
    static var buildNumber: String { Bundle.main.appBuild }
}
