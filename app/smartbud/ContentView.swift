//
//  ContentView.swift
//
//  Created by Iorest on 3/6/22.
//
//  Thin shell over `ContentViewModel`. The view no longer holds the 13
//  `@AppStorage` values, the first-run defaults block, the iCloud
//  currency migration, the update-sheet scheduling, or the duplicated
//  notification-authorization reconciliation — those all live in
//  `ContentViewModel`. `AppLock` stays here because the lock/unlock
//  transitions need to fire on the same scene-phase events that drive
//  `.task` / `.onChange(of: scenePhase)`.
//

import SwiftUI
import WidgetKit

// `appLanguage` and `colourScheme` are declared here as direct
// `@AppStorage` even though `ContentViewModel` already mirrors them. The
// copies on the view model are `@ObservationIgnored` (see
// `ContentViewModel.swift:34-39` for the Swift 6 redeclaration reason),
// so they do NOT trigger view updates on change. These two declarations
// are the observation anchor that makes `.environment(\.locale, …)` and
// `.preferredColorScheme(…)` re-evaluate when the user picks a new
// language or theme in Settings. The values stay in sync with
// `contentVM` because both sides read the same App Group key.

struct ContentView: View {
    @Environment(AppLockViewModel.self) var appLockVM
    @Environment(\.scenePhase) var scenePhase
    @State private var contentVM = ContentViewModel()

    @AppStorage(AppDefaultsKey.appLanguage, store: .appGroup) var appLanguage: String = ""
    @AppStorage("colourScheme", store: .appGroup) var colourScheme: Int = 0

    var body: some View {
        @Bindable var contentVM = contentVM

        GeometryReader { proxy in
            let topEdge = proxy.safeAreaInsets.top
            let bottomEdge = proxy.safeAreaInsets.bottom

            HomeView(topEdge: topEdge, bottomEdge: bottomEdge == 0 ? 15 : bottomEdge)
                .ignoresSafeArea(.all, edges: .bottom)
                .preferredColorScheme(colourScheme == 1 ? .light : colourScheme == 2 ? .dark : nil)
                .environment(\.locale, appLanguage.isEmpty ? Locale.current : Locale(identifier: appLanguage))
                .onChange(of: appLanguage) { _, _ in
                    WidgetCenter.shared.reloadAllTimelines()
                }
                .fullScreenCover(isPresented: $contentVM.showIntro) {
                    WelcomeSheetView()
                }
                .fullScreenCover(isPresented: $contentVM.showUpdate) {
                    UpdateAlert()
                }
                .onAppear {
                    contentVM.updateInsets(top: topEdge, bottom: bottomEdge)
                }
        }
        .ignoresSafeArea(.keyboard)
        .task {
            if appLockVM.isAppLockEnabled {
                appLockVM.appLockValidation()
            }
            contentVM.bootstrap()
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .background, .inactive:
                if appLockVM.isAppLockEnabled {
                    appLockVM.isAppUnLocked = false
                }
            case .active:
                contentVM.handleSceneBecameActive()
            @unknown default:
                break
            }
        }
    }
}
