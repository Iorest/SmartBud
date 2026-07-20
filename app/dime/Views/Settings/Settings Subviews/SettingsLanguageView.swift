//
//  SettingsLanguageView.swift
//  dime
//
//  Lets the user pick the in-app display language. The selected code is stored
//  in `appLanguage` (UserDefaults) and applied at the root of the SwiftUI tree
//  via `.environment(\.locale, …)`, so `String(localized:)` lookups resolve to
//  the chosen language immediately without restarting the app.
//
//  Empty string means "follow system locale".
//

import SwiftUI

struct SettingsLanguageView: View {
    @AppLanguage var appLanguage: String = ""

    @Environment(\.dismiss) var dismiss
    @Environment(SettingsViewModel.self) var settingsVM

    @Namespace var animation

    var body: some View {
        VStack(spacing: 10) {
            Text(String(localized: "Language"))
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
                        withAnimation(.easeIn(duration: 0.15)) {
                            appLanguage = code
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            dismiss()
                        }
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
            .background(Color.SettingsBackground, in: RoundedRectangle(cornerRadius: 9))
        }
        .modifier(SettingsSubviewModifier())
    }
}
