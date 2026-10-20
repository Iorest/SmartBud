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
    }

    // To disable the AppLock in UserDefaults
    func disableAppLock() {
        UserDefaults.appGroup.set(false, forKey: Self.appLockKey)
        isAppLockEnabled = false
    }

    // To Publish the AppLock state
    func getAppLockState() {
        isAppLockEnabled = UserDefaults.appGroup.bool(forKey: Self.appLockKey)
    }

    // Checking if the device is having BioMetric hardware and enrolled
    func checkIfBioMetricAvailable() -> Bool {
        var error: NSError?
        let laContext = LAContext()

        let isBiometricAvailable = laContext.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)

        // Surface biometric-unavailable errors via the existing
        // `enrollmentError` flag so the UI can show a recovery hint.
        // Do not log here: the error is a user-actionable state, not
        // a developer diagnostic.
        enrollmentError = !isBiometricAvailable || error != nil

        return isBiometricAvailable
    }

    // This method used to change the AppLock state.
    // If user is going to enable the AppLock then 'appLockState' should be 'true' and vice versa
    func appLockStateChange(appLockState: Bool) {
        let laContext = LAContext()
        if checkIfBioMetricAvailable() {
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
        let laContext = LAContext()
        if checkIfBioMetricAvailable() {
            let reason = "Enable App Lock"
            laContext.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, error in
                if success {
                    Task { @MainActor in
                        self.isAppUnLocked = true
                    }
                } else if error != nil {
                    Task { @MainActor in
                        // Surface auth failure to the UI so the user
                        // can see why unlock did not succeed.
                        self.enrollmentError = true
                    }
                }
            }
        } else {
            openBiometricSettings()
        }
    }
}
