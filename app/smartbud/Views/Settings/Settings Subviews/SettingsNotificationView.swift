//
//  SettingsNotificationView.swift
//  smartbud
//
//  Created by Iorest on 5/11/23.
//

import Foundation
import SwiftUI
import UserNotifications
#if os(macOS)
import AppKit
#endif

@MainActor
struct SettingsNotificationsView: View {

  @AppStorage("showNotifications", store: .appGroup)
  var showNotifications: Bool = false
  @AppStorage("notificationsEnabled", store: .appGroup)
  var notificationsEnabled: Bool = true
  @AppStorage("notificationOption", store: .appGroup)
  var option: Int = 1

  @State var customTime = Date.now

  var center = UNUserNotificationCenter.current()

  var body: some View {
    VStack(spacing: SBSpace.medium) {
      VStack(spacing: 0) {
        Toggle(isOn: $showNotifications) {
          Text(String.appLocalized("Enable Notifications"))
            .font(.body)
        }
        .tint(.green)
        .padding(.vertical, 4)
      }
      .padding(.horizontal, SBSpace.medium)
      .padding(.vertical, SBSpace.xs)
      .background(
        Color.SecondaryBackground,
        in: RoundedRectangle(cornerRadius: SBRadius.card, style: .continuous)
      )

      if showNotifications {
        VStack(spacing: 0) {
          Picker(String.appLocalized("Reminder time"), selection: $option) {
            Text(String.appLocalized("Every morning (8:00 AM)")).tag(1)
            Text(String.appLocalized("Every evening (8:00 PM)")).tag(2)
            Text(String.appLocalized("Custom Time")).tag(3)
          }
          .pickerStyle(.inline)
          .labelsHidden()

          if option == 3 {
            Divider()
            DatePicker(
              String.appLocalized("Custom notification time"),
              selection: $customTime,
              displayedComponents: .hourAndMinute
            )
            .padding(.vertical, SBSpace.xs)
          }
        }
        .padding(.horizontal, SBSpace.medium)
        .padding(.vertical, SBSpace.xs)
        .background(
          Color.SecondaryBackground,
          in: RoundedRectangle(cornerRadius: SBRadius.card, style: .continuous)
        )
        .transition(.opacity)
      }

      Text(String.appLocalized("A daily reminder to log today's expenses."))
        .font(.footnote)
        .foregroundStyle(Color.SubtitleText)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, SBSpace.xxs)

      Spacer()
    }
    .animation(.easeInOut(duration: 0.2), value: showNotifications)
    .onChange(of: showNotifications) { _, isOn in
      if isOn {
        requestEnable()
      } else {
        center.removeAllPendingNotificationRequests()
      }
    }
    .onChange(of: option) { _, newValue in
      if newValue == 3 {
        storeCustomTime()
      }
      newNotification()
    }
    .onChange(of: customTime) { _, _ in
      storeCustomTime()
      newNotification()
    }
    .onAppear {
      let defaults = UserDefaults.appGroup
      if defaults.object(forKey: "customHour") != nil,
         defaults.object(forKey: "customMinute") != nil {
        var components = DateComponents()
        components.hour = defaults.integer(forKey: "customHour")
        components.minute = defaults.integer(forKey: "customMinute")
        if let date = Calendar.current.date(from: components) {
          customTime = date
        }
      }
    }
    .padding(.horizontal, SBSpace.medium)
    .navigationTitle(String.appLocalized("Notifications"))
    #if os(iOS)
    .navigationBarTitleDisplayMode(.inline)
    #endif
  }

  /// Called after the switch turns on: ask the system for permission and
  /// flip the switch back if it is refused.
  private func requestEnable() {
    Task { @MainActor in
      let status = await center.notificationSettings().authorizationStatus

      switch status {
      case .notDetermined:
        do {
          let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
          if granted {
            newNotification()
          } else {
            showNotifications = false
            notificationsEnabled = false
          }
        } catch {
          showNotifications = false
          notificationsEnabled = false
        }
      case .denied:
        showNotifications = false
        notificationsEnabled = false
        openNotificationSettings()
      default:
        newNotification()
      }
    }
  }

  private func openNotificationSettings() {
    #if os(macOS)
    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") {
      NSWorkspace.shared.open(url)
    }
    #else
    if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
      UIApplication.shared.open(settingsURL)
    }
    #endif
  }

  private func storeCustomTime() {
    let components = Calendar.current.dateComponents([.hour, .minute], from: customTime)
    UserDefaults.appGroup.set(components.hour ?? 0, forKey: "customHour")
    UserDefaults.appGroup.set(components.minute ?? 0, forKey: "customMinute")
  }
}

@MainActor
func newNotification() {
  UNUserNotificationCenter.current().removeAllPendingNotificationRequests()

  let content = UNMutableNotificationContent()
  content.title = String.appLocalized("Keep the streak going!")
  content.subtitle = String.appLocalized("Remember to input your expenses today.")
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
