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
    @State private var dataRepo = DataRepository.shared

    @AppStorage(AppDefaultsKey.appLanguage, store: .appGroup) var appLanguage: String = ""
    @AppStorage("colourScheme", store: .appGroup) var colourScheme: Int = 0

    var body: some View {
        @Bindable var contentVM = contentVM

        GeometryReader { proxy in
            let topEdge = proxy.safeAreaInsets.top
            let bottomEdge = proxy.safeAreaInsets.bottom == 0 ? 15 : proxy.safeAreaInsets.bottom

            ZStack(alignment: .top) {
                HomeView(topEdge: topEdge,
                         isInFallbackMode: dataRepo.isInFallbackMode)
                    .ignoresSafeArea(.all, edges: .bottom)
                    .preferredColorScheme(colourScheme == 1 ? .light : colourScheme == 2 ? .dark : nil)
                    .environment(\.locale, appLanguage.isEmpty ? Locale.current : Locale(identifier: appLanguage))
                    .onChange(of: appLanguage) { _, _ in
                        WidgetCenter.shared.reloadAllTimelines()
                    }
                    .fullScreenPresentation(isPresented: $contentVM.showIntro) {
                        WelcomeSheetView()
                    }

                if let saveError = dataRepo.lastSaveError {
                    SBSaveErrorBanner(message: saveError) {
                        dataRepo.clearSaveError()
                    }
                    .padding(.horizontal, SBSpace.m)
                    .padding(.bottom, bottomEdge + 68)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.easeOut(duration: 0.2), value: dataRepo.lastSaveError != nil)
        }
        .ignoresSafeArea(.keyboard)
        .task {
            if appLockVM.isAppLockEnabled {
                appLockVM.appLockValidation()
            }
            contentVM.bootstrap()
            // Verify Pro entitlement + load SK2 products on launch so the
            // first time the user opens the Pro screen it's already
            // correct (no "Not Pro" flash on a valid subscriber, no
            // "Coming Soon" placeholder on a configured build).
            await SubscriptionManager.shared.bootstrap()
            // Stamp first-launch date; the actual review prompt is
            // fired by `ReviewRequester.recordTransactionCreated()` at
            // the 3rd, 10th, and 25th transaction rather than here, so
            // the user is asked *after* they have something to rate.
            ReviewRequester.recordAppLaunch()
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

/// Shown when the SwiftData container booted degraded (no App Group, no
/// iCloud, or a corrupted store). Lives outside `ContentView` so the Mac
/// layout can place it inside the detail column instead of over the sidebar.
struct FallbackSyncBanner: View {
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "icloud.slash.fill")
                .font(.body.weight(.semibold))
                .foregroundStyle(.white)
            VStack(alignment: .leading, spacing: 2) {
                Text(String.appLocalized(SettingsKey.bannerFallbackTitle))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Text(String.appLocalized(SettingsKey.bannerFallbackBody))
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.92))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: SBRadius.chip, style: .continuous)
                .fill(Theme.Brand.warning.opacity(0.92))
        )
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}
