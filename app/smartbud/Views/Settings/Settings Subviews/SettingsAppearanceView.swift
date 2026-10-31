//
//  SettingsAppearanceView.swift
//  smartbud
//
//  Created by Iorest on 5/11/23.
//

import Foundation
import SwiftUI

struct SettingsAppearanceView: View {
    @AppStorage("colourScheme", store: .appGroup)
    var colourScheme: Int = 0
    /// Lock Screen widgets are readable without unlocking, so amounts are
    /// hidden there by default.
    @AppStorage("hideLockWidgetAmounts", store: .appGroup)
    var hideLockWidgetAmounts: Bool = true

    @Environment(\.dismiss) var dismiss

    private let options = [String.appLocalized("System"), String.appLocalized("Light"), String.appLocalized("Dark")]

    var body: some View {
        Form {
            Section {
                Picker(String.appLocalized("Theme"), selection: $colourScheme) {
                    ForEach(options.indices, id: \.self) { index in
                        Text(options[index]).tag(index)
                    }
                }
                #if os(iOS)
                .pickerStyle(.inline)
                .labelsHidden()
                #endif
                .accessibilityIdentifier(AccessibilityID.settingsAppearancePicker)
            } footer: {
                Text(String.appLocalized("Applied immediately."))
            }

            Section {
                Toggle(isOn: $hideLockWidgetAmounts) {
                    Text(String.appLocalized("Hide amounts on Lock Screen widgets"))
                }
            } footer: {
                Text(String.appLocalized(
                    "Lock Screen budget widgets show the spent percentage instead of amounts."))
            }
        }
        #if os(macOS)
        .formStyle(.grouped)
        #endif
        .navigationTitle(String.appLocalized("Appearance"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onChange(of: colourScheme) { _, _ in
            dismiss()
        }
    }
}
