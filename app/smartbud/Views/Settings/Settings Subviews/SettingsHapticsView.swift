//
//  SettingsHapticsView.swift
//  smartbud
//
//  Created by Iorest on 5/11/23.
//

import Foundation
import SwiftUI

struct SettingsHapticsView: View {
    @AppStorage("haptics", store: .appGroup)
    var hapticType: Int = 1

    @State private var hapticTrigger = 0

    private let options = [
        String.appLocalized("None"),
        String.appLocalized("Subtle"),
        String.appLocalized("Excessive")
    ]

    var body: some View {
        Form {
            Section {
                Picker(String.appLocalized("Haptic Feedback"), selection: $hapticType) {
                    ForEach(options.indices, id: \.self) { index in
                        Text(options[index]).tag(index)
                    }
                }
                #if os(iOS)
                .pickerStyle(.inline)
                .labelsHidden()
                #endif
            } footer: {
                Text(String.appLocalized("Haptics fire on keypad taps, submits and deletes."))
            }
        }
        #if os(macOS)
        .formStyle(.grouped)
        #endif
        .navigationTitle(String.appLocalized("Haptic Feedback"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onChange(of: hapticType) { _, newValue in
            if newValue > 0 { hapticTrigger += 1 }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
    }
}
