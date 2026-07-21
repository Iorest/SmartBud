//
//  SettingsAppIconView.swift
//  smartbud
//
//  Created by Iorest on 5/11/23.
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
      actualFileName: "AppIcon", exampleFileName: "AppIcon_EG",
      displayName: String(localized: "Deep Sea · 深青"),
      displaySubtitle: String(
        localized: "The original default app icon.")),
    AppIconBundle(
      actualFileName: "AppIcon1", exampleFileName: "AppIcon1_EG",
      displayName: String(localized: "Midnight · 紫袋辉光"),
      displaySubtitle: String(
        localized: "Original design with a glowing amber tie on a deep violet bag.")),
    AppIconBundle(
      actualFileName: "AppIcon2", exampleFileName: "AppIcon2_EG",
      displayName: String(localized: "Plum · 紫袋"),
      displaySubtitle: String(
        localized: "The classic bag in a brighter plum tone, no glow.")),
    AppIconBundle(
      actualFileName: "AppIcon3", exampleFileName: "AppIcon3_EG",
      displayName: String(localized: "Indigo · 深紫"),
      displaySubtitle: String(
        localized: "A deeper violet bag with a soft amber tie on indigo.")),
    AppIconBundle(
      actualFileName: "AppIcon4", exampleFileName: "AppIcon4_EG",
      displayName: String(localized: "Sky · 浅蓝"),
      displaySubtitle: String(
        localized: "A soft sky background with a white bag and yellow tie.")),
    AppIconBundle(
      actualFileName: "AppIcon5", exampleFileName: "AppIcon5_EG",
      displayName: String(localized: "Sunset · 黄昏"),
      displaySubtitle: String(
        localized: "A teal-to-gold gradient backdrop with a deep teal bag.")),
    AppIconBundle(
      actualFileName: "AppIcon6", exampleFileName: "AppIcon6_EG",
      displayName: String(localized: "Aqua · 浅青辉光"),
      displaySubtitle: String(
        localized: "A bright aqua background with a glowing yellow tie on a light bag."))
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
        UIApplication.shared.setAlternateIconName(newValue == "AppIcon" ? nil : newValue)
      }
    }
    .modifier(SettingsSubviewModifier())
  }
}
