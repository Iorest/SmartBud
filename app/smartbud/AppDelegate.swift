//
//  AppDelegate.swift
//  smartbud
//
//  Created by Iorest on 24/8/22.
//
//  Hosts the small set of UIKit-level hooks that SwiftUI's `App` lifecycle
//  cannot cover directly. Home-screen quick actions (3D Touch / long-press
//  app icon) are now handled by `SceneDelegate` under the iOS 26 UIScene
//  lifecycle — `launchOptions[.shortcutItem]` and
//  `application(_:performActionFor:completionHandler:)` are deprecated
//  in favor of `UIScene.ConnectionOptions.shortcutItem` and
//  `windowScene(_:performActionFor:completionHandler:)` respectively.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Note: in-app language switching is handled by
        // `String.appLocalized(...)` in `AppLocale.swift`, which resolves
        // through the user's `appLanguage` pick on every call. The
        // historical `LanguageBundleInstaller.install()` Bundle swizzle
        // was abandoned
        // because (a) it crashed on iOS 26.5.1 (EXC_BAD_ACCESS at
        // objc_retain(0x1)) and (b) String Catalog entries cannot be
        // served through a swizzled
        // `Bundle.localizedString(forKey:value:table:)`.

        return true
    }

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        // SwiftUI manages scene lifecycle itself, but we still need a
        // UISceneDelegate on the configuration so the home-screen quick
        // action hooks (cold start via `UIScene.ConnectionOptions.shortcutItem`
        // and warm case via `windowScene(_:performActionFor:completionHandler:)`)
        // are delivered. `SceneDelegate` forwards both to
        // `UIApplication.open`, which in turn triggers the `.onOpenURL`
        // handlers in the SwiftUI view tree.
        let config = UISceneConfiguration(name: "Default", sessionRole: connectingSceneSession.role)
        config.delegateClass = SceneDelegate.self
        return config
    }
}
