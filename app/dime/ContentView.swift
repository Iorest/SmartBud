//
//  ContentView.swift
//
//  Created by Rafael Soh on 3/6/22.
//

import SwiftUI
import WidgetKit

struct ContentView: View {
    @EnvironmentObject var appLockVM: AppLockViewModel

    @AppStorage("colourScheme", store: UserDefaults(suiteName: "group.com.rafaelsoh.dime")) var colourScheme: Int = 0
    @Environment(\.scenePhase) var scenePhase
    @AppStorage("showNotifications", store: UserDefaults(suiteName: "group.com.rafaelsoh.dime")) var showNotifications: Bool = false
    @AppStorage("notificationsEnabled", store: UserDefaults(suiteName: "group.com.rafaelsoh.dime")) var notificationsEnabled: Bool = true

    @AppStorage("firstLaunch", store: UserDefaults(suiteName: "group.com.rafaelsoh.dime")) var firstLaunch: Bool = true

    // adds category orders
    @AppStorage("dataMigration1", store: UserDefaults(suiteName: "group.com.rafaelsoh.dime")) var dataMigration1: Bool = true

    // converts category colors to hex codes
    @AppStorage("dataMigration2", store: UserDefaults(suiteName: "group.com.rafaelsoh.dime")) var dataMigration2: Bool = true

    @AppStorage("currency", store: UserDefaults(suiteName: "group.com.rafaelsoh.dime")) var currency: String = Locale.current.currency?.identifier ?? "USD"

    @State var showIntro: Bool = false
    @State var showUpdate: Bool = false

    @AppStorage("topEdge", store: UserDefaults(suiteName: "group.com.rafaelsoh.dime")) var savedTopEdge: Double = 30
    @AppStorage("bottomEdge", store: UserDefaults(suiteName: "group.com.rafaelsoh.dime")) var savedBottomEdge: Double = 15

    @AppStorage("previousVersion", store: UserDefaults(suiteName: "group.com.rafaelsoh.dime")) var previousVersionString: String = "Version \(UIApplication.appVersion ?? "") (\(UIApplication.buildNumber ?? ""))"

    @AppStorage("showUpdateSheet", store: UserDefaults(suiteName: "group.com.rafaelsoh.dime")) var showUpdateSheet: Bool = true

    @AppStorage("appLanguage", store: UserDefaults(suiteName: "group.com.rafaelsoh.dime")) var appLanguage: String = ""

    var body: some View {
        GeometryReader { proxy in
            let topEdge = proxy.safeAreaInsets.top
            let bottomEdge = proxy.safeAreaInsets.bottom

            HomeView(topEdge: topEdge, bottomEdge: bottomEdge == 0 ? 15 : bottomEdge)
                .ignoresSafeArea(.all, edges: .bottom)
                .preferredColorScheme(colourScheme == 1 ? .light : colourScheme == 2 ? .dark : nil)
                .environment(\.locale, appLanguage.isEmpty ? Locale.current : Locale(identifier: appLanguage))
                .fullScreenCover(isPresented: $showIntro) {
                    WelcomeSheetView()
                }
                .fullScreenCover(isPresented: $showUpdate) {
                    UpdateAlert()
                }
                .onAppear {
                    savedTopEdge = topEdge
                    savedBottomEdge = bottomEdge
                }
        }
        .ignoresSafeArea(.keyboard)
        .onAppear {
            if appLockVM.isAppLockEnabled {
                appLockVM.appLockValidation()
            }

            // First-run language bootstrap: if the user hasn't picked yet
            // (appLanguage == "" = "follow system"), and the system is
            // Chinese, snap to a concrete zh-Hans / zh-Hant so the Settings
            // row shows a real choice ("Simplified Chinese" / "Traditional Chinese")
            // instead of the abstract "System" placeholder. Users can still
            // revert to "System" from the language picker.
            if appLanguage.isEmpty {
                let langCode = Locale.current.language.languageCode?.identifier
                let scriptCode = Locale.current.language.script?.identifier
                if langCode == "zh" {
                    appLanguage = (scriptCode == "Hant") ? "zh-Hant" : "zh-Hans"
                }
            }

            let defaults =
                UserDefaults(suiteName: "group.com.rafaelsoh.dime") ?? UserDefaults.standard

            if defaults.object(forKey: "firstDayOfMonth") == nil {
                defaults.set(1, forKey: "firstDayOfMonth")
            }

            if firstLaunch {
                showIntro = true
                firstLaunch = false
                showUpdateSheet = false
                dataMigration1 = false
                dataMigration2 = false

                defaults.set(1, forKey: "firstWeekday")
                defaults.set(1, forKey: "haptics")
                defaults.set(1, forKey: "firstDayOfMonth")
                defaults.set(1, forKey: "notificationOption")
                defaults.set(false, forKey: "confetti")
                defaults.set(false, forKey: "chromatic")
                defaults.set(true, forKey: "showCents")
                defaults.set(true, forKey: "animated")

                if NSUbiquitousKeyValueStore.default.string(forKey: "currency") == nil {
                    NSUbiquitousKeyValueStore.default.set(Locale.current.currency?.identifier ?? "USD", forKey: "currency")
                } else {
                    currency = NSUbiquitousKeyValueStore.default.string(forKey: "currency")!
                }

                defaults.set(2, forKey: "numberEntryType")
            } else {
                if let holdingCurrency = NSUbiquitousKeyValueStore.default.string(forKey: "currency") {
                    currency = holdingCurrency
                } else {
                    currency = Locale.current.currency?.identifier ?? "USD"
                    NSUbiquitousKeyValueStore.default.set(Locale.current.currency?.identifier ?? "USD", forKey: "currency")
                }
            }

            // Skip CoreData-specific migrations - SwiftData models don't need them
            dataMigration1 = false
            dataMigration2 = false

            if showUpdateSheet {
                showUpdate = true
                showUpdateSheet = false
            }

            UNUserNotificationCenter.current().getNotificationSettings { settings in
                if settings.authorizationStatus == .authorized {
                    Task { @MainActor in
                        if !showNotifications && notificationsEnabled == false {
                            showNotifications = true
                            notificationsEnabled = true
                            newNotification()
                        }
                    }
                } else if settings.authorizationStatus == .denied {
                    Task { @MainActor in
                        notificationsEnabled = false

                        if showNotifications {
                            showNotifications = false
                            UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
                        }
                    }
                }
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background || newPhase == .inactive {
                if appLockVM.isAppLockEnabled {
                    appLockVM.isAppUnLocked = false
                }
            } else if newPhase == .active {
                UNUserNotificationCenter.current().getNotificationSettings { settings in
                    if settings.authorizationStatus == .authorized {
                        Task { @MainActor in
                            if !showNotifications && notificationsEnabled == false {
                                showNotifications = true
                                notificationsEnabled = true
                                newNotification()
                            }
                        }
                    } else if settings.authorizationStatus == .denied {
                        Task { @MainActor in
                            notificationsEnabled = false

                            if showNotifications {
                                showNotifications = false
                                UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
                            }
                        }
                    }
                }
            }
        }
    }
}
