//
//  SettingsLanguageView.swift
//  smartbud
//
//  Lets the user pick the in-app display language. The selected code is stored
//  in `appLanguage` (UserDefaults). On pick, the view terminates the process
//  via `exit(0)` so the next cold launch reads the new `appLanguage` and
//  every `String.appLocalized(...)` call resolves to it. The app does NOT
//  try to refresh in-place because `String.appLocalized` reads UserDefaults
//  directly and bypasses the `\.locale` environment, so the only reliable
//  way to switch every visible string is a full process restart.
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

    /// When `true`, the view shows a brief "Restarting…" overlay before
    /// calling `exit(0)`. We can't just exit immediately because the user
    /// needs visual feedback that the language change was accepted.
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
                    ProgressView()
                        .controlSize(.large)
                    Text(String.appLocalized("Restarting…"))
                        .font(.system(.callout, design: .rounded).weight(.semibold))
                        .foregroundStyle(Color.PrimaryText)
                }
                .padding(28)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: GlassRadius.card, style: .continuous))
            }
        }
    }

    /// Persist the new pick, flash a "Restarting…" overlay so the user
    /// gets visual feedback, then `exit(0)`. iOS will show the home
    /// screen; the next launch reads the new `appLanguage` and every
    /// `String.appLocalized(...)` call resolves to it.
    private func selectLanguage(_ code: String) {
        guard code != appLanguage else {
            dismiss()
            return
        }
        withAnimation(.easeIn(duration: 0.15)) {
            appLanguage = code
            isRestarting = true
        }
        // Give SwiftUI a tick to commit the animation, then kill the process.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            #if canImport(UIKit)
                exit(0)
            #endif
        }
    }
}
