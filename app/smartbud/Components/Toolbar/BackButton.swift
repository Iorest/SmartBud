//
//  BackButton.swift
//  smartbud
//
//  Created by Yumi on 2023-10-24.
//

import SwiftUI

struct BackButton: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ToolbarButton(systemName: "chevron.left", accessibilityLabel: String.appLocalized("Back")) {
            dismiss()
        }
    }
}
