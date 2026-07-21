//
//  StepperButtons.swift
//  smartbud
//
//  Created by Iorest on 5/11/23.
//

import Foundation
import SwiftUI

struct StepperButtonView: View {
    let left: Bool
    let disabled: Bool
    var action: () -> Void

    var body: some View {
        Button(action: {
            self.action()
        }) {
            Image(systemName: left ? "chevron.left" : "chevron.right")
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(Color.SubtitleText)
                .padding(8)
                .background(Circle().fill(.clear))
                .glassChip(in: Circle(), interactive: !disabled)
                .opacity(disabled ? 0.3 : 1)
        }
        .accessibilityLabel(left ? String.appLocalized("Previous") : String.appLocalized("Next"))
    }
}
