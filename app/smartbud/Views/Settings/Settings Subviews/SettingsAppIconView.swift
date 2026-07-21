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

  // Holds the icon the user just tapped. While non-nil, an in-app
  // confirmation dialog is shown. Only when the user confirms do we
  // commit the change to `activeIcon`, which then triggers the
  // iOS-rendered SpringBoard alert via `.onChange` below. This gives
  // us a chance to phrase the prompt in the in-app language, which
  // the system alert cannot do.
  @State private var pendingIcon: AppIconBundle?

  let options: [AppIconBundle] = [
    AppIconBundle(
      actualFileName: "AppIcon", exampleFileName: "AppIcon_EG",
      displayName: String.appLocalized("Deep Sea · 深青"),
      displaySubtitle: String.appLocalized("The original default app icon.")),
    AppIconBundle(
      actualFileName: "AppIcon1", exampleFileName: "AppIcon1_EG",
      displayName: String.appLocalized("Midnight · 紫袋辉光"),
      displaySubtitle: String.appLocalized("Original design with a glowing amber tie on a deep violet bag.")),
    AppIconBundle(
      actualFileName: "AppIcon2", exampleFileName: "AppIcon2_EG",
      displayName: String.appLocalized("Plum · 紫袋"),
      displaySubtitle: String.appLocalized("The classic bag in a brighter plum tone, no glow.")),
    AppIconBundle(
      actualFileName: "AppIcon3", exampleFileName: "AppIcon3_EG",
      displayName: String.appLocalized("Indigo · 深紫"),
      displaySubtitle: String.appLocalized("A deeper violet bag with a soft amber tie on indigo.")),
    AppIconBundle(
      actualFileName: "AppIcon4", exampleFileName: "AppIcon4_EG",
      displayName: String.appLocalized("Sky · 浅蓝"),
      displaySubtitle: String.appLocalized("A soft sky background with a white bag and yellow tie.")),
    AppIconBundle(
      actualFileName: "AppIcon5", exampleFileName: "AppIcon5_EG",
      displayName: String.appLocalized("Sunset · 黄昏"),
      displaySubtitle: String.appLocalized("A teal-to-gold gradient backdrop with a deep teal bag.")),
    AppIconBundle(
      actualFileName: "AppIcon6", exampleFileName: "AppIcon6_EG",
      displayName: String.appLocalized("Aqua · 浅青辉光"),
      displaySubtitle: String.appLocalized("A bright aqua background with a glowing yellow tie on a light bag."))
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
            // Don't mutate `activeIcon` yet — the `.onChange` below
            // would immediately fire `setAlternateIconName` and the
            // SpringBoard alert. Stage the choice in `pendingIcon`
            // so the in-app confirmation can run first.
            pendingIcon = options[index]
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
    .confirmationDialog(
      pendingIcon?.displayName ?? String.appLocalized("Change App Icon"),
      isPresented: Binding(
        get: { pendingIcon != nil },
        set: { if !$0 { pendingIcon = nil } }
      ),
      titleVisibility: .visible
    ) {
      Button(String.appLocalized("Change")) {
        if let pending = pendingIcon {
          // Committing here fires the `.onChange` above, which in
          // turn asks SpringBoard to swap the icon and show its
          // own (un-translatable) confirmation alert.
          activeIcon = pending.actualFileName
        }
        pendingIcon = nil
      }
      Button(String.appLocalized("Cancel"), role: .cancel) {
        pendingIcon = nil
      }
    } message: {
      Text(String.appLocalized("Switch to this icon?"))
    }
  }
}
