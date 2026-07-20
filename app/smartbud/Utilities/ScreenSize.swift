//
//  ScreenSize.swift
//  smartbud
//
//  Swift 6 / iOS 26 safe replacement for `UIScreen.main` which was deprecated
//  in iOS 26. Captures the active scene's screen bounds once at first access.
//  For single-window iPhone this matches `UIScreen.main`; for multi-window iPad
//  it returns the first scene's bounds (the iOS 26-mandated default).
//

import UIKit

@MainActor
enum ScreenSize {
    /// The active screen's width in points. Captured lazily from the first
    /// connected `UIWindowScene`. Defaults to a typical iPhone width (390) if
    /// no scene is yet connected.
    static var width: CGFloat {
        bounds.width
    }

    /// The active screen's height in points.
    static var height: CGFloat {
        bounds.height
    }

    /// The active screen's bounds, or a typical iPhone fallback.
    static var bounds: CGRect {
        if let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }) ?? UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first
        {
            return scene.screen.bounds
        }
        return CGRect(x: 0, y: 0, width: 390, height: 844)
    }
}
