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
// All App Lock related methods will be handled here

@MainActor
@Observable
class AppLockViewModel{
    // Publishing the applock state from user defaults
    var isAppLockEnabled: Bool = false
    // Publishing if the app is curretly unlocked or not
    var isAppUnLocked: Bool = false

    var enrollmentError: Bool = false

    init() {
        getAppLockState()
    }

    // To enable the AppLock in UserDefaults
    func enableAppLock() {
        UserDefaults.standard.set(true, forKey: "appLockEnabled")
        isAppLockEnabled = true
    }

    // To disable the AppLock in UserDefaults
    func disableAppLock() {
        UserDefaults.standard.set(false, forKey: "appLockEnabled")
        isAppLockEnabled = false
    }

    // To Publish the AppLock state
    func getAppLockState() {
        isAppLockEnabled = UserDefaults.standard.bool(forKey: "appLockEnabled")
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
            if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(settingsURL)
            }
        }
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
            if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(settingsURL)
            }
        }
    }
}
