//
//  SettingsLanguageView.swift
//  smartbud
//
//  Lets the user pick the in-app display language. The selected code is stored
//  in `appLanguage` (UserDefaults). On pick, the view triggers a process
//  restart so the next cold launch reads the new `appLanguage` and every
//  `String.appLocalized(...)` call resolves to it. The app does NOT try to
//  refresh in-place because `String.appLocalized` reads UserDefaults directly
//  and bypasses the `\.locale` environment, so the only reliable way to switch
//  every visible string is a full process restart.
//
//  Restart is attempted via `UIApplication.perform(#selector(NSXPCConnection.suspend))`
//  — a private selector that historically caused the OS to terminate and
//  immediately re-spawn the app, keeping the user in-app. On iOS 26+ this
//  trick is neutered (selector resolves but no crash), so we also schedule
//  an `exit(0)` fallback 2.5s later: the user lands on the home screen and
//  can tap the icon to reopen with the new language. Not in-place, but
//  recoverable instead of being stuck on the "Restarting…" overlay.
//
//  Empty string means "follow system locale".
//

import SwiftUI
#if canImport(UIKit)
    import UIKit
#endif

struct SettingsLanguageView: View {
    @AppStorage(AppDefaultsKey.appLanguage, store: .appGroup) var appLanguage: String = ""

    @Environment(\.dismiss) var dismiss
    @Environment(SettingsViewModel.self) var settingsVM

    @Namespace var animation

    /// When `true`, the view shows a "Saved. Please reopen the app." overlay
    /// with a checkmark while we wait for the 2.5s `exit(0)` timer to fire.
    /// iOS does not let an app relaunch itself, so the user has to tap the
    /// app icon to come back. The overlay is honest about this rather than
    /// pretending an automatic restart is happening.
    @State private var isRestarting = false

    var body: some View {
        ZStack {
            VStack(spacing: 10) {
                Text(String.appLocalized("Language"))
                    .font(.system(.title3, design: .rounded).weight(.semibold))
                    .foregroundStyle(Color.PrimaryText)
                    .frame(maxWidth: .infinity)
                    .overlay(alignment: .leading) {
                        Button {
                            dismiss()
                        } label: {
                            SettingsBackButton()
                        }
                    }
                    .padding(.bottom, 20)

                VStack(spacing: 0) {
                    ForEach(SettingsViewModel.supportedLanguageCodes, id: \.self) { code in
                        Button {
                            selectLanguage(code)
                        } label: {
                            HStack {
                                Text(settingsVM.displayName(for: code))
                                    .font(.system(.body, design: .rounded))
                                    .foregroundStyle(Color.PrimaryText)

                                Spacer()

                                if appLanguage == code {
                                    Image(systemName: "checkmark")
                                        .font(.system(.subheadline, design: .rounded).weight(.medium))
                                        .foregroundStyle(Color.DarkIcon.opacity(0.6))
                                        .matchedGeometryEffect(id: "tick", in: animation)
                                        .accessibilityHidden(true)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .contentShape(Rectangle())
                            .padding(.vertical, 9)
                            .overlay(alignment: .bottom) {
                                if code != SettingsViewModel.supportedLanguageCodes.last {
                                    Divider()
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(appLanguage == code ? [.isButton, .isSelected] : .isButton)
                    }
                }
                .padding(.horizontal, 15)
                .background(Color.SettingsBackground, in: RoundedRectangle(cornerRadius: GlassRadius.chip))
            }
            .modifier(SettingsSubviewModifier())
            .opacity(isRestarting ? 0.3 : 1.0)
            .disabled(isRestarting)

            if isRestarting {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 36, weight: .semibold))
                        .foregroundStyle(Color.IncomeGreen)
                    Text(String.appLocalized("PleaseReopenApp"))
                        .font(.system(.callout, design: .rounded).weight(.semibold))
                        .foregroundStyle(Color.PrimaryText)
                        .multilineTextAlignment(.center)
                }
                .padding(28)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: GlassRadius.card, style: .continuous))
            }
        }
    }

    /// Persist the new pick, flash a "Restarting…" overlay so the user
    /// gets visual feedback, then ask SpringBoard to relaunch the process.
    /// `NSXPCConnection.suspend` is a private selector that causes the OS
    /// to terminate and immediately re-spawn the app — the user stays in
    /// the app rather than being dumped to the home screen as `exit(0)`
    /// would do.
    private func selectLanguage(_ code: String) {
        guard code != appLanguage else {
            dismiss()
            return
        }
        withAnimation(.easeIn(duration: 0.15)) {
            appLanguage = code
            isRestarting = true
        }

        // Strategy:
        // 1) Try the standard iOS "self-relaunch" trick first — a private
        //    selector that crashes the process gracefully; SpringBoard
        //    then immediately re-spawns the app and the user stays in-app.
        // 2) On iOS 26+ Apple has silently neutered `NSXPCConnection.suspend`
        //    — `perform(...)` returns without effect, and the app would sit
        //    on the "Restarting…" overlay forever. After 2.5s, fall back to
        //    `exit(0)`: the user lands on the home screen, then taps the
        //    app icon to reopen with the new language applied. Not as nice
        //    as in-place relaunch, but at least the user can recover.

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            #if canImport(UIKit)
                UIApplication.shared.perform(#selector(NSXPCConnection.suspend))
            #endif
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            #if canImport(UIKit)
                exit(0)
            #endif
        }
    }
}
