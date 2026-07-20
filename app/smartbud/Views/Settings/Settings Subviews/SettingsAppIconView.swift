//
//  SettingsAppIconView.swift
//  smartbud
//
//  Created by Rafael Soh on 5/11/23.
//

import Foundation
import SwiftUI

struct AppIconBundle: Hashable {
  let actualFileName: String
  let exampleFileName: String
  let displayName: String
  let displaySubtitle: String
}

struct SettingsAppIconView: View {
  @AppStorage("activeIcon", store: .appGroup)
  var activeIcon: String = "AppIcon"
  @Environment(\.dismiss) var dismiss

  let options: [AppIconBundle] = [
    AppIconBundle(
      actualFileName: "AppIcon1", exampleFileName: "AppIcon1_EG",
      displayName: String(localized: "V2.0"),
      displaySubtitle: String(
        localized: "Designed by the brilliant @rudra_dsigns, check out his work on Twitter.")),
    AppIconBundle(
      actualFileName: "AppIcon2", exampleFileName: "AppIcon2_EG",
      displayName: String(localized: "Unicorn"),
      displaySubtitle: String(
        localized:
          "It definitely isn't becoming one, but it never hurts to keep dreaming."))
  ]

  @Namespace var animation

  var body: some View {
    VStack(spacing: 10) {
      Text("App Icon")
        .font(.system(.title3, design: .rounded).weight(.semibold))
        .foregroundStyle(Color.PrimaryText)
        .frame(maxWidth: .infinity)
        .overlay(alignment: .leading) {
          Button {
            dismiss()
          } label: {
            SettingsBackButton()
          }
        }
        .padding(.bottom, 20)

      VStack(spacing: 0) {
        ForEach(options.indices, id: \.self) { index in
          Button {
            withAnimation {
              activeIcon = options[index].actualFileName
            }
          } label: {
            HStack(spacing: 13) {
              Image(options[index].exampleFileName)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 70, height: 70)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .shadow(color: .black.opacity(0.15), radius: 5, x: 5, y: 5)
                .accessibilityHidden(true)

              VStack(alignment: .leading, spacing: 3) {
                Text(options[index].displayName)
                  .font(.system(.body, design: .rounded))
                  .foregroundStyle(Color.PrimaryText)

                Text(options[index].displaySubtitle)
                  .font(.system(.caption, design: .rounded))
                  .foregroundStyle(Color.SubtitleText)
              }

              Spacer()

              Image(systemName: "checkmark")
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(activeIcon == options[index].actualFileName
                    ? Color.DarkIcon.opacity(0.6)
                    : Color.SettingsBackground)
                .matchedGeometryEffect(id: "tick", in: animation)
                .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .padding(.vertical, 15)
            .overlay(alignment: .bottom) {
              if index < (options.count - 1) {
                Divider()
              }
            }
          }
          .buttonStyle(.plain)
          .accessibilityLabel(options[index].displayName)
          .accessibilityAddTraits(activeIcon == options[index].actualFileName
              ? [.isButton, .isSelected]
              : .isButton)
        }
      }
      .padding(.horizontal, 15)
      .background(Color.SettingsBackground, in: RoundedRectangle(cornerRadius: 9))
      .onChange(of: activeIcon) { _, newValue in
        UIApplication.shared.setAlternateIconName(newValue)
      }
    }
    .modifier(SettingsSubviewModifier())
  }
}
