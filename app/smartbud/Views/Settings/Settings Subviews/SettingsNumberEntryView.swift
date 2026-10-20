//
//  SettingsNumberEntryView.swift
//  smartbud
//
//  Created by Iorest on 5/11/23.
//

import Foundation
import SwiftUI

struct SettingsNumberEntryView: View {
    @AppStorage("numberEntryType", store: .appGroup)
    var numberEntryType: Int = 1

    private let options = [
        String.appLocalized(SettingsKey.numberEntryType1),
        String.appLocalized(SettingsKey.numberEntryType2)
    ]

    var body: some View {
        Form {
            Section {
                Picker(String.appLocalized("Number Entry Method"), selection: $numberEntryType) {
                    ForEach(options.indices, id: \.self) { index in
                        Text(options[index]).tag(index + 1)
                    }
                }
                #if os(iOS)
                .pickerStyle(.inline)
                .labelsHidden()
                #endif
            } footer: {
                Text(String.appLocalized("Decimal entry adds a decimal key to the "
                     + "keypad; whole numbers only hides it."))
            }
        }
        #if os(macOS)
        .formStyle(.grouped)
        #endif
        .navigationTitle(String.appLocalized("Number Entry Method"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}
