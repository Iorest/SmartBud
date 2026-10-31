//
//  Authentication.swift
//  Bonsai
//
//  Created by Iorest on 7/7/22.
//

import Foundation
import LocalAuthentication
import SwiftUI
import Observation
#if os(macOS)
import AppKit
#endif
// All App Lock related methods will be handled here

@MainActor
@Observable
class AppLockViewModel {
    private static let appLockKey = "appLockEnabled"

    // Publishing the applock state from user defaults
    var isAppLockEnabled: Bool = false
    // Publishing if the app is curretly unlocked or not
    var isAppUnLocked: Bool = false

    var enrollmentError: Bool = false

    init() {
        migrateLegacyAppLockKey()
        getAppLockState()
        #if DEBUG
        // QA hook: writes the same key the Settings toggle writes, so the rest
        // of the launch takes the normal locked path. Has to happen here and
        // not in `UITestFixture`: this object is built before `SmartBudApp`
        // clears the defaults.
        if UITestFixture.forcesAppLock {
            UserDefaults.appGroup.set(true, forKey: Self.appLockKey)
            isAppLockEnabled = true
        }
        #endif
        // A cold launch while the lock is enabled is locked until Face ID /
        // passcode succeeds; intents read this flag too.
        AppLockGate.setUnlocked(!isAppLockEnabled)
    }

    /// One-time migration: App Lock used to be stored in
    /// `UserDefaults.standard` while the rest of the app moved to the
    /// app group suite. Move the old value over and remove it.
    private func migrateLegacyAppLockKey() {
        let standard = UserDefaults.standard
        guard standard.object(forKey: Self.appLockKey) != nil else { return }
        UserDefaults.appGroup.set(standard.bool(forKey: Self.appLockKey), forKey: Self.appLockKey)
        standard.removeObject(forKey: Self.appLockKey)
    }

    // To enable the AppLock in UserDefaults
    func enableAppLock() {
        UserDefaults.appGroup.set(true, forKey: Self.appLockKey)
        isAppLockEnabled = true
        AppLockGate.setUnlocked(true)
    }

    // To disable the AppLock in UserDefaults
    func disableAppLock() {
        UserDefaults.appGroup.set(false, forKey: Self.appLockKey)
        isAppLockEnabled = false
        AppLockGate.setUnlocked(true)
    }

    // To Publish the AppLock state
    func getAppLockState() {
        isAppLockEnabled = UserDefaults.appGroup.bool(forKey: Self.appLockKey)
        if !isAppLockEnabled { AppLockGate.setUnlocked(true) }
    }

    /// Re-locks the app: called on background/inactive so a returning session
    /// must authenticate again, and so intents are refused meanwhile.
    func lock() {
        isAppUnLocked = false
        AppLockGate.setUnlocked(false)
    }

    /// Whether the device can authenticate the user at all — Face ID/Touch ID
    /// *or* the device passcode. Checking biometrics only meant a lockout (or
    /// a temporarily disabled Face ID) reported "unavailable" and the app sent
    /// the user to Settings without ever offering the passcode, leaving them
    /// with no way to unlock or turn the lock off.
    func canAuthenticate() -> Bool {
        var error: NSError?
        let laContext = LAContext()
        let available = laContext.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error)
        enrollmentError = !available || error != nil
        return available
    }

    // This method used to change the AppLock state.
    // If user is going to enable the AppLock then 'appLockState' should be 'true' and vice versa
    func appLockStateChange(appLockState: Bool) {
        let laContext = LAContext()
        if canAuthenticate() {
            var reason = ""
            if appLockState {
                reason = "Provice Touch ID/Face ID to enable App Lock"
            } else {
                reason = "Provice Touch ID/Face ID to disable App Lock"
            }

            laContext.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, error in
                if success {
                    Task { @MainActor in
                        if appLockState {
                            self.enableAppLock()
                            self.isAppUnLocked = true
                        } else {
                            self.disableAppLock()
                            self.isAppUnLocked = true
                        }
                    }
                } else if error != nil {
                    Task { @MainActor in
                        // Surface auth failure (e.g. user cancel, lockout)
                        // to the UI via the existing enrollmentError flag.
                        self.enrollmentError = true
                    }
                }
            }
        } else {
            openBiometricSettings()
        }
    }

    /// Sends the user to the OS screen where biometrics can be enrolled when
    /// the device has none available.
    private func openBiometricSettings() {
        #if os(macOS)
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy") {
            NSWorkspace.shared.open(url)
        }
        #else
        if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsURL)
        }
        #endif
    }

    // This method will call on every launch of the app if user has enabled AppLock
    func appLockValidation() {
        #if DEBUG
        // QA hooks. Without a passcode the simulator can neither evaluate the
        // policy nor fall back to one, so a forced lock is asserted as-is and
        // an unlock attempt succeeds immediately instead of bouncing the app
        // into Settings.
        if UITestFixture.forcesAppLock {
            if UITestFixture.unlocksWithoutPrompt {
                isAppUnLocked = true
                AppLockGate.setUnlocked(true)
                enrollmentError = false
            }
            return
        }
        #endif
        let laContext = LAContext()
        if canAuthenticate() {
            let reason = "Enable App Lock"
            laContext.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, error in
                if success {
                    Task { @MainActor in
                        self.isAppUnLocked = true
                        AppLockGate.setUnlocked(true)
                        // A successful authentication clears any stale "Face
                        // ID unavailable" hint from an earlier attempt.
                        self.enrollmentError = false
                    }
                } else if let error = error as? LAError,
                          error.code == .biometryNotEnrolled || error.code == .passcodeNotSet {
                    // A cancelled prompt is not a configuration problem.
                    Task { @MainActor in self.enrollmentError = true }
                }
            }
        } else {
            openBiometricSettings()
        }
    }
}
