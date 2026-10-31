//
//  SettingsRowLink.swift
//  smartbud
//
//  Navigation row helper shared by every settings section.
//

import SwiftUI

// MARK: - Navigation row

extension SettingsView {

    @ViewBuilder
    func settingsLink(
        _ route: SettingsRoute,
        _ icon: String,
        _ colour: Int,
        _ title: String,
        _ value: String?
    ) -> some View {
      NavigationLink(value: route) {
        HStack(spacing: 0) {
          SettingsRowView(icon: icon, colour: colour, title: title, value: value)
          #if os(macOS)
          Image(systemName: "chevron.right")
            .font(.caption.weight(.semibold))
            .foregroundStyle(Color.SubtitleText)
            .padding(.leading, 8)
          #endif
        }
      }
      .accessibilityIdentifier(AccessibilityID.settingsRow(route.accessibilityKey))
    }
}

// MARK: - Presentations

/// Presentations owned by Settings. One slot, because two `fullScreenCover`
/// modifiers on the same view cancel each other out on iOS.
enum SettingsSheet: String, Identifiable {
    case importData
    case pro

    var id: String { rawValue }
}
