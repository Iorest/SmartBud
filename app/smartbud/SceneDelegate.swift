//
//  SceneDelegate.swift
//  smartbud
//
//  Handles home screen quick actions (3D Touch / long-press app icon) for
//  the iOS 26 UIScene lifecycle. SwiftUI's `App` lifecycle does not
//  surface `UIApplicationShortcutItem` directly, and on iOS 26 the
//  `UIApplication.LaunchOptionsKey.shortcutItem` path
//  (`launchOptions[.shortcutItem]`) is deprecated in favor of
//  `UIScene.ConnectionOptions.shortcutItem`. The matching warm-case hook
//  is `windowScene(_:performActionFor:completionHandler:)` (which is
//  `@Sendable`-annotated under Swift 6 concurrency, unlike the old
//  UIApplicationDelegate variant).
//
//  In both cases we forward the shortcut's `type` to `UIApplication.open`
//  so the existing `.onOpenURL` handlers in the SwiftUI view tree can
//  react (see HomeView.swift, LogView.swift).
//

#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

final class SceneDelegate: NSObject, UIWindowSceneDelegate {

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        // Cold-start quick action: the user launched the app by tapping a
        // home-screen shortcut. Defer slightly so the root view is mounted
        // and the openURL environment value is wired up before we trigger
        // it.
        if let shortcut = connectionOptions.shortcutItem,
           let url = URL(string: shortcut.type) {
            DispatchQueue.main.async {
                UIApplication.shared.open(url)
            }
        }
    }

    func windowScene(
        _ windowScene: UIWindowScene,
        performActionFor shortcutItem: UIApplicationShortcutItem,
        completionHandler: @escaping @Sendable (Bool) -> Void
    ) {
        // Warm case: app was already running in the background, user tapped
        // a home-screen shortcut. The completion handler is `@Sendable`
        // under iOS 26, so we can pass it straight through to
        // `UIApplication.open`.
        guard let url = URL(string: shortcutItem.type) else {
            completionHandler(false)
            return
        }
        UIApplication.shared.open(url, options: [:], completionHandler: completionHandler)
    }
}
