//
//  SettingsLanguageView.swift
//  smartbud
//
//  Lets the user pick the in-app display language. The selected code is stored
//  in `appLanguage` (UserDefaults). `String.appLocalized` reads that value
//  directly and bypasses the `\.locale` environment, so the change takes
//  effect on the next cold launch; the view tells the user to reopen the app
//  rather than terminating itself (an `exit(0)` restart is an App Review
//  risk and has no supported API).
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

    /// Shows the "Saved. Please reopen the app." overlay briefly, then
    /// dismisses back to Settings. iOS does not let an app relaunch itself,
    /// so the overlay is honest about what the user has to do.
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

    /// Persist the new pick and show an overlay telling the user to reopen
    /// the app. Deliberately does NOT terminate the process: `exit(0)` and
    /// the `NSXPCConnection.suspend` private selector are App Review risks,
    /// and iOS gives no supported way to relaunch in place.
    private func selectLanguage(_ code: String) {
        guard code != appLanguage else {
            dismiss()
            return
        }
        withAnimation(.easeIn(duration: 0.15)) {
            appLanguage = code
            isRestarting = true
        }

        // Let the confirmation register, then return to Settings so the user
        // can close the app from the app switcher.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            isRestarting = false
            dismiss()
        }
    }
}
