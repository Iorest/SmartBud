//
//  File.swift
//  smartbud
//
//  Created by Iorest on 4/11/23.
//

import Foundation
import SwiftUI

struct DeleteButton: View {
    let text: String
    let red: Bool

    var body: some View {
        Text(text)
            .font(.title3.weight(.semibold))
            .foregroundStyle(red ? Color.white : Color.PrimaryText.opacity(0.9))
            .frame(height: 45)
            .frame(maxWidth: .infinity)
            .background {
                if red {
                    Capsule().fill(Color.AlertRed)
                } else {
                    Capsule().fill(.clear)
                }
            }
            .glassEffect(
                red ? Glass.regular.tint(Color.AlertRed) : .regular,
                in: RoundedRectangle(cornerRadius: SBRadius.chip, style: .continuous)
            )
    }
}
