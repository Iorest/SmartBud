//
//  DetailedBudgetViewTopBarButtons.swift
//  smartbud
//
//  Created by Iorest on 4/11/23.
//

import Foundation
import SwiftUI

struct DetailedBudgetViewTopBarButton: View {
    var imageName: String
    var color: Color
    var label: String
    var action: () -> Void

    var body: some View {
        Button(action: {
            self.action()
        }) {
            Image(systemName: imageName)
                .font(.system(.callout, design: .rounded).weight(.semibold))
                .foregroundStyle(color)
                .padding(8)
//                .frame(width: 30, height: 30)
                .background(Circle().fill(.clear))
                .tintedGlassChip(color.opacity(0.5), in: Circle())
                .contentShape(Circle())
        }
        .accessibilityLabel(label)
    }
}
