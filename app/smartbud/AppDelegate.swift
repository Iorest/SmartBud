//
//  AppDelegate.swift
//  smartbud
//
//  Created by Iorest on 24/8/22.
//
//  Handles home screen quick actions (3D Touch / long-press app icon).
//  Replaces the previous SceneDelegate: SwiftUI's `App` lifecycle does not
//  expose `UIApplicationShortcutItem` directly, so we route both the cold-start
//  case (`launchOptions[.shortcutItem]`) and the warm case
//  (`application(_:performActionFor:completionHandler:)`) into `openURL`
//  so the existing `.onOpenURL` handlers in the view tree can react.
//

import SwiftUI
import UIKit

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        NSLog("[AppDelegate] didFinishLaunching")
        // Swap Bundle.main → LanguageBundle so that Foundation's
        // `String(localized:)` resolves through the user's in-app
        // language pick rather than the system locale. Must run before
        // any view body / locale lookup so the very first render uses
        // the right translation.
        LanguageBundleInstaller.install()
        NSLog("[AppDelegate] LanguageBundle installed")

        // Cold-start quick action: the user launched the app by tapping a
        // home-screen shortcut. Forward its `type` to openURL so the same
        // `.onOpenURL` handlers in the view tree can react.
        if let shortcut = launchOptions?[.shortcutItem] as? UIApplicationShortcutItem,
           let url = URL(string: shortcut.type) {
            // Defer slightly so the root view is mounted and the openURL
            // environment value is wired up before we trigger it.
            DispatchQueue.main.async {
                UIApplication.shared.open(url)
            }
        }
        return true
    }

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        // SwiftUI manages scene lifecycle itself; do not attach a custom
        // SceneDelegate (the previous SceneDelegate.swift was removed as
        // legacy pre-iOS-13 boilerplate).
        UISceneConfiguration(name: "Default", sessionRole: connectingSceneSession.role)
    }

    func application(
        _ application: UIApplication,
        performActionFor shortcutItem: UIApplicationShortcutItem,
        completionHandler: @escaping (Bool) -> Void
    ) {
        // Warm case: app was already running in the background, user tapped
        // a home-screen shortcut.
        guard let url = URL(string: shortcutItem.type) else {
            completionHandler(false)
            return
        }
        UIApplication.shared.open(url, options: [:], completionHandler: completionHandler)
    }
}
