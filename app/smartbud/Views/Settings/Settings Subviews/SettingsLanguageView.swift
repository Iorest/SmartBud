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

struct SettingsLanguageView: View {
    @AppStorage(AppDefaultsKey.appLanguage, store: .appGroup) var appLanguage: String = ""

    @Environment(\.dismiss) var dismiss
    @Environment(SettingsViewModel.self) var settingsVM

    /// Shows the "Saved. Please reopen the app." overlay briefly, then
    /// dismisses back to Settings. iOS does not let an app relaunch itself,
    /// so the overlay is honest about what the user has to do.
    @State private var isRestarting = false

    var body: some View {
        List {
            Section {
                ForEach(SettingsViewModel.supportedLanguageCodes, id: \.self) { code in
                    Button {
                        selectLanguage(code)
                    } label: {
                        HStack {
                            Text(settingsVM.displayName(for: code))
                                .font(.body)
                                .foregroundStyle(Color.PrimaryText)

                            Spacer(minLength: SBSpace.xs)

                            if appLanguage == code {
                                Image(systemName: "checkmark")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(appLanguage == code ? [.isButton, .isSelected] : .isButton)
                }
            } footer: {
                Text(String.appLocalized("Reopening the app is required for a language change to take effect."))
            }
        }
        .navigationTitle(String.appLocalized("Language"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .disabled(isRestarting)
        .opacity(isRestarting ? 0.3 : 1)
        .overlay {
            if isRestarting {
                VStack(spacing: SBSpace.s) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.largeTitle)
                        .foregroundStyle(Color.IncomeGreen)
                    Text(String.appLocalized("PleaseReopenApp"))
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(Color.PrimaryText)
                        .multilineTextAlignment(.center)
                }
                .padding(SBSpace.l)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: SBRadius.card, style: .continuous))
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.15), value: isRestarting)
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
        appLanguage = code
        isRestarting = true

        // Let the confirmation register, then return to Settings so the user
        // can close the app from the app switcher.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            isRestarting = false
            dismiss()
        }
    }
}
