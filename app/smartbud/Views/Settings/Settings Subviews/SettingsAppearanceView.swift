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
            } footer: {
                Text(String.appLocalized("Close and reload app for change to take effect."))
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
