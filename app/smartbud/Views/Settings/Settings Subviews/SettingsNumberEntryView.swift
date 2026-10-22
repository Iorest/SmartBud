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

    /// Shared with `TransactionView`: keep the form open after saving.
    @AppStorage("continuousEntry", store: .appGroup)
    var continuousEntry: Bool = false

    /// Shared with `HomeView`: open the entry form right after launch.
    @AppStorage("launchIntoEntry", store: .appGroup)
    var launchIntoEntry: Bool = false

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

            Section {
                Toggle(String.appLocalized("Open a new entry on launch"),
                       isOn: $launchIntoEntry)
            } footer: {
                Text(String.appLocalized(
                    "Skips the ledger and drops you straight into the number pad when the app opens."))
            }

            Section {
                Toggle(String.appLocalized("Save and Continue"), isOn: $continuousEntry)
            } footer: {
                Text(String.appLocalized(
                    "Keeps the form open after saving, with the category and date kept, "
                        + "so you can log several transactions in a row."))
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
