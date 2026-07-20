//
//  SettingsNotificationView.swift
//  dime
//
//  Created by Rafael Soh on 5/11/23.
//

import Foundation
import SwiftUI

@MainActor
struct SettingsNotificationsView: View {
  @Environment(\.dismiss) var dismiss

  @AppStorage("showNotifications", store: .appGroup)
  var showNotifications: Bool = false
  @AppStorage("notificationsEnabled", store: .appGroup)
  var notificationsEnabled: Bool = true
  @State var option = 1
  @State var customTime = Date.now

  var center = UNUserNotificationCenter.current()

  @Namespace var animation

  var body: some View {
    VStack {
      Text("Notifications")
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
        Button {
          if showNotifications {
            withAnimation(.easeInOut(duration: 0.2)) {
              center.removeAllPendingNotificationRequests()
              showNotifications.toggle()
            }
          } else {
            Task { @MainActor in
              let status = await center.notificationSettings().authorizationStatus
              if status == .notDetermined {
                do {
                  let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
                  if granted {
                    withAnimation(.easeInOut(duration: 0.2)) {
                      showNotifications.toggle()
                      newNotification()
                    }
                  } else {
                    notificationsEnabled = false
                  }
                } catch {
                  print(error.localizedDescription)
                  notificationsEnabled = false
                }
              } else if status == .denied {
                notificationsEnabled = false

                if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                  await UIApplication.shared.open(settingsURL)
                }

              } else {
                withAnimation(.easeInOut(duration: 0.2)) {
                  showNotifications.toggle()
                  if showNotifications {
                    newNotification()
                  }
                }
              }
            }
          }
        } label: {
          HStack {
            Text("Enable Notifications")
              .font(.system(.body, design: .rounded))
              .foregroundStyle(Color.PrimaryText)

            Spacer()

            ZStack(alignment: showNotifications ? .trailing : .leading) {
              Capsule()
                .frame(width: 42, height: 28)
                .foregroundStyle(showNotifications ? .green : .gray.opacity(0.8))

              Circle()
                .foregroundStyle(Color.white)
                .padding(2)
                .frame(width: 28, height: 28)
                .matchedGeometryEffect(id: "toggle", in: animation)
            }
          }
          .frame(maxWidth: .infinity)
          .contentShape(Rectangle())
          .padding(.vertical, 9)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(showNotifications ? [.isButton, .isSelected] : .isButton)
      }
      .padding(.horizontal, 15)
      .background(Color.SettingsBackground, in: RoundedRectangle(cornerRadius: 9))
      .padding(.bottom, 20)

      if showNotifications {
        VStack(spacing: 0) {
          Button {
            withAnimation(.easeIn(duration: 0.15)) {
              option = 1
            }
          } label: {
            HStack {
              Text("Every morning (8:00 AM)")
                .font(.system(.body, design: .rounded))
                .foregroundStyle(Color.PrimaryText)

              Spacer()

              if option == 1 {
                Image(systemName: "checkmark")
                  .font(.system(.subheadline, design: .rounded))
                  .foregroundStyle(Color.DarkIcon.opacity(0.6))
                  .matchedGeometryEffect(id: "tick", in: animation)
                  .accessibilityHidden(true)
              }
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .padding(.vertical, 9)
            .overlay(alignment: .bottom) {
              Divider()
            }
          }
          .buttonStyle(.plain)
          .accessibilityAddTraits(option == 1 ? [.isButton, .isSelected] : .isButton)

          Button {
            withAnimation(.easeIn(duration: 0.15)) {
              option = 2
            }
          } label: {
            HStack {
              Text("Every evening (8:00 PM)")
                .font(.system(.body, design: .rounded))
                .foregroundStyle(Color.PrimaryText)

              Spacer()

              if option == 2 {
                Image(systemName: "checkmark")
                  .font(.system(.subheadline, design: .rounded))
                  .foregroundStyle(Color.DarkIcon.opacity(0.6))
                  .matchedGeometryEffect(id: "tick", in: animation)
                  .accessibilityHidden(true)
              }
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .padding(.vertical, 9)
            .overlay(alignment: .bottom) {
              Divider()
            }
          }
          .buttonStyle(.plain)
          .accessibilityAddTraits(option == 2 ? [.isButton, .isSelected] : .isButton)

          Button {
            withAnimation(.easeIn(duration: 0.15)) {
              option = 3
            }
          } label: {
            HStack {
              Text("Custom Time")
                .font(.system(.body, design: .rounded))
                .foregroundStyle(Color.PrimaryText)

              Spacer()

              if option == 3 {
                DatePicker(
                  "Custom notification time", selection: $customTime,
                  displayedComponents: .hourAndMinute
                )
                .labelsHidden()

                Image(systemName: "checkmark")
                  .font(.system(.subheadline, design: .rounded))
                  .foregroundStyle(Color.DarkIcon.opacity(0.6))
                  .matchedGeometryEffect(id: "tick", in: animation)
                  .accessibilityHidden(true)
              }
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .padding(.vertical, 9)
          }
          .buttonStyle(.plain)
          .accessibilityAddTraits(option == 3 ? [.isButton, .isSelected] : .isButton)
        }
        .padding(.horizontal, 15)
        .background(Color.SettingsBackground, in: RoundedRectangle(cornerRadius: 9))
        .onChange(of: option) { _, newValue in
          let defaults = UserDefaults.appGroup
          defaults.set(
            option, forKey: "notificationOption")

          if newValue == 3 {
            let components = Calendar.current.dateComponents([.hour, .minute], from: customTime)

            defaults.set(
              components.hour!, forKey: "customHour")
            defaults.set(
              components.minute!, forKey: "customMinute")
          }

          newNotification()
        }
        .onChange(of: customTime) { _, _ in
          let defaults = UserDefaults.appGroup
          let components = Calendar.current.dateComponents([.hour, .minute], from: customTime)

          defaults.set(
            components.hour!, forKey: "customHour")
          defaults.set(
            components.minute!, forKey: "customMinute")

          newNotification()
        }
        .onAppear {
          let defaults = UserDefaults.appGroup
          if defaults.object(
            forKey: "notificationOption") != nil {
            option = defaults.integer(
              forKey: "notificationOption")
          }

          if defaults.object(forKey: "customHour")
            != nil
            && defaults.object(forKey: "customMinute")
              != nil {
            var components = DateComponents()
            components.hour = defaults.integer(
              forKey: "customHour")
            components.minute = defaults.integer(
              forKey: "customMinute")
            customTime = Calendar.current.date(from: components)!
          }
        }
      }
    }
    .modifier(SettingsSubviewModifier())
  }
}

@MainActor
func newNotification() {
  UNUserNotificationCenter.current().removeAllPendingNotificationRequests()

  let content = UNMutableNotificationContent()
  content.title = String(localized: "Keep the streak going!")
  content.subtitle = String(localized: "Remember to input your expenses today.")
  content.sound = UNNotificationSound.default

  // show this notification five seconds from now
  var components = DateComponents()
  var option = 1

  if UserDefaults.appGroup.object(forKey: "notificationOption")
    != nil {
    option = UserDefaults.appGroup.integer(
      forKey: "notificationOption")
  }

  if option == 1 {
    components.hour = 8
    components.minute = 0
  } else if option == 2 {
    components.hour = 20
    components.minute = 0
  } else {
    if UserDefaults.appGroup.object(forKey: "customHour") != nil,
      UserDefaults.appGroup.object(forKey: "customMinute") != nil {
      components.hour = UserDefaults.appGroup.integer(
        forKey: "customHour")
      components.minute = UserDefaults.appGroup.integer(
        forKey: "customMinute")
    } else {
      components.hour = 8
      components.minute = 0
    }
  }

  let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)

  // choose a random identifier
  let request = UNNotificationRequest(
    identifier: UUID().uuidString, content: content, trigger: trigger)

  // add our notification request
  UNUserNotificationCenter.current().add(request)
}
