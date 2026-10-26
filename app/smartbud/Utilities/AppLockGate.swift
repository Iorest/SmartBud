//
//  AppLockGate.swift
//  smartbud
//
//  App Lock state that outlives the UI process, so Shortcuts and Siri cannot
//  read or write a ledger the user has explicitly hidden.
//
//  `AppLockViewModel` owns the interactive state; this session flag mirrors it
//  into the App Group so an intent (which may run without any scene) can make
//  the same decision. The flag is cleared on lock/background and on launch
//  while the lock is enabled, and set only after a successful unlock.
//

import Foundation

enum AppLockGate {
    static let enabledKey = "appLockEnabled"
    static let sessionKey = "appSessionUnlocked"

    /// True when the lock is enabled and this session has not been unlocked.
    static var isLocked: Bool {
        guard UserDefaults.appGroup.bool(forKey: enabledKey) else { return false }
        return !UserDefaults.appGroup.bool(forKey: sessionKey)
    }

    static func setUnlocked(_ unlocked: Bool) {
        UserDefaults.appGroup.set(unlocked, forKey: sessionKey)
    }
}

/// Thrown by App Intents when the lock is up. Reads and writes are both
/// refused: the payload itself (notes, totals) is what the lock protects.
enum AppLockError: LocalizedError {
    case locked

    var errorDescription: String? {
        String.appLocalized("请先解锁 SmartBud，再使用快捷指令。")
    }
}
