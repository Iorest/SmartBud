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
        Button {
            self.action()
        } label: {
            Image(systemName: left ? "chevron.left" : "chevron.right")
                .font(.subheadline)
                .foregroundStyle(Color.SubtitleText)
                .padding(8)
                .background(Circle().fill(.clear))
                .systemChip(in: Circle(), interactive: !disabled)
                .opacity(disabled ? 0.3 : 1)
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .accessibilityLabel(left ? String.appLocalized("Previous") : String.appLocalized("Next"))
    }
}
