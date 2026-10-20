//
//  SettingsBackButton.swift
//  smartbud
//
//  Created by Iorest on 5/11/23.
//

import Foundation
import SwiftUI

struct SettingsBackButton: View {
  var body: some View {
    Image(systemName: "chevron.left")
      .font(.subheadline.weight(.semibold))
      .foregroundStyle(Color.SubtitleText)
      .padding(8)
      .frame(minWidth: 44, minHeight: 44)
      .contentShape(Rectangle())
      .background(Circle().fill(.clear))
      .systemChip(in: Circle())
      .accessibilityLabel(String.appLocalized("Back"))
  }
}
