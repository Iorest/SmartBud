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
  @AppStorage("budgetForecastEnabled", store: .appGroup)
  var budgetForecastEnabled: Bool = true
  @AppStorage("budgetAlertsEnabled", store: .appGroup)
  var budgetAlertsEnabled: Bool = false
  @AppStorage("forecastExcludeOutliers", store: .appGroup)
  var excludeOutliers: Bool = true
  @AppStorage("budgetAlertFrequency", store: .appGroup)
  var alertFrequency: Int = 0

  @State var customTime = Date.now
  @State private var subscription = SubscriptionManager.shared
  @State private var showProUpsell = false

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
      .padding(.vertical, SBSpace.extraSmall)
      .background(
        Color.SecondaryBackground,
        in: RoundedRectangle(cornerRadius: SBRadius.card, style: .continuous)
      )

      if showNotifications {
        VStack(spacing: 0) {
          Picker(String.appLocalized("Reminder time"), selection: $option) {
            Text(String.appLocalized("Every morning (8:00 AM)")).tag(1)
            Text(String.appLocalized("Every evening (8:00 PM)")).tag(2)
            HStack(spacing: 4) {
              Text(String.appLocalized("Custom Time"))
              if !subscription.isUnlocked(.customReminderTime) {
                Image(systemName: "lock.fill")
                  .font(.caption2.weight(.semibold))
                  .foregroundStyle(Color.SubtitleText)
              }
            }
            .tag(3)
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
            .padding(.vertical, SBSpace.extraSmall)
          }
        }
        .padding(.horizontal, SBSpace.medium)
        .padding(.vertical, SBSpace.extraSmall)
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


      VStack(spacing: 0) {
        Toggle(isOn: $budgetForecastEnabled) {
          Text(String.appLocalized("Budget forecast"))
            .font(.body)
        }
        .tint(.green)
        .padding(.vertical, 4)

        if budgetForecastEnabled {
          Divider()
          Toggle(isOn: $budgetAlertsEnabled) {
            Text(String.appLocalized("Budget alerts"))
              .font(.body)
          }
          .tint(.green)
          .padding(.vertical, 4)

          if budgetAlertsEnabled {
            Divider()
            Toggle(isOn: $excludeOutliers) {
              Text(String.appLocalized("Exclude one-off large entries"))
                .font(.footnote)
            }
            .padding(.vertical, 4)
            Picker(String.appLocalized("Alert frequency"), selection: $alertFrequency) {
              Text(String.appLocalized("Once per budget period")).tag(0)
              Text(String.appLocalized("At most once a day")).tag(1)
            }
            .pickerStyle(.inline)
          }
        }
      }
      .padding(.horizontal, SBSpace.medium)
      .padding(.vertical, SBSpace.extraSmall)
      .background(
        Color.SecondaryBackground,
        in: RoundedRectangle(cornerRadius: SBRadius.card, style: .continuous)
      )
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
      if newValue == 3, !subscription.isUnlocked(.customReminderTime) {
        // Morning/evening stay free; only the custom time is Pro.
        option = 1
        showProUpsell = true
        return
      }
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
    .proUpsell(isPresented: $showProUpsell)
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
  // Re-entering this screen restores `customTime`, which fires the change
  // handler; without this guard a reminder the user switched off was
  // scheduled again while the toggle still read Off.
  let enabled = UserDefaults.appGroup.object(forKey: "showNotifications") as? Bool ?? false
  guard enabled else {
    UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    return
  }
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

// MARK: - Budget alerts

/// Evaluates the budget numbers against the persisted alert settings and posts
/// at most one local notification per kind and budget. Called at launch, on
/// return to the foreground and when the budget screen appears — never from a
/// render loop, so a user cannot be bombarded while scrolling.
@MainActor
func refreshBudgetAlerts(now: Date = .now) {
  let defaults = UserDefaults.appGroup
  guard defaults.object(forKey: "budgetForecastEnabled") as? Bool ?? true,
        defaults.object(forKey: "budgetAlertsEnabled") as? Bool ?? false,
        defaults.object(forKey: "showNotifications") as? Bool ?? false
  else { return }

  let budgetVM = BudgetViewModel.shared
  budgetVM.load()
  let all = BookScope.scoped(DataRepository.shared.fetch(TransactionModel.self),
                             \.bookID, selected: BookSelection.current())
  let calendar = Calendar.current
  let excludeOutliers = defaults.object(forKey: "forecastExcludeOutliers") as? Bool ?? true
  var snapshots = [BudgetAlertSnapshot]()

  for main in budgetVM.mainBudgets {
    let start = BudgetRollover.roll(startDate: main.startDate, type: main.type) ?? main.startDate
    let end = BudgetPeriod.endDate(from: start, type: main.type)
    let entries = all.compactMap { txn -> BudgetForecastEntry? in
      guard let date = txn.date, date >= start, date <= now else { return nil }
      return BudgetForecastEntry(date: date, spend: txn.spendBaseAmount)
    }
    snapshots.append(BudgetAlertSnapshot(
      budgetID: "main|\(main.bookID?.uuidString ?? "")",
      periodKey: BudgetAlertEvaluator.periodKey(for: start, calendar: calendar),
      budget: main.amount,
      spent: main.amount - budgetVM.leftoverOverall(main),
      forecast: BudgetForecast.estimate(entries: entries, budget: main.amount,
                                        periodStart: start, periodEnd: end,
                                        excludeOutliers: excludeOutliers,
                                        now: now, calendar: calendar)))
  }

  for budget in budgetVM.budgets {
    guard let categoryID = budget.category?.id else { continue }
    let start = BudgetRollover.roll(startDate: budget.startDate, type: budget.type) ?? budget.startDate
    let end = BudgetPeriod.endDate(from: start, type: budget.type)
    let entries = all.compactMap { txn -> BudgetForecastEntry? in
      guard txn.category?.id == categoryID, let date = txn.date,
            date >= start, date <= now else { return nil }
      return BudgetForecastEntry(date: date, spend: txn.spendBaseAmount)
    }
    snapshots.append(BudgetAlertSnapshot(
      budgetID: budget.id.uuidString,
      periodKey: BudgetAlertEvaluator.periodKey(for: start, calendar: calendar),
      budget: budget.amount,
      spent: budget.amount - budgetVM.leftover(budget),
      forecast: BudgetForecast.estimate(entries: entries, budget: budget.amount,
                                        periodStart: start, periodEnd: end,
                                        excludeOutliers: excludeOutliers,
                                        now: now, calendar: calendar)))
  }

  let frequency = BudgetAlertFrequency(rawValue: defaults.integer(forKey: "budgetAlertFrequency"))
    ?? .oncePerPeriod
  let history = defaults.dictionary(forKey: "budgetAlertHistory") as? [String: String] ?? [:]
  let decision = BudgetAlertEvaluator.requests(for: snapshots, enabled: true,
                                               now: now, frequency: frequency,
                                               history: history, calendar: calendar)
  defaults.set(decision.history, forKey: "budgetAlertHistory")

  let center = UNUserNotificationCenter.current()
  for request in decision.requests {
    let content = UNMutableNotificationContent()
    content.sound = .default
    content.threadIdentifier = "smartbud.budget"
    switch request.kind {
    case .usage80:
      content.title = String.appLocalized("Budget 80% used")
      content.body = String.appLocalized("You have used 80% of this period's budget.")
    case .projectedOverspend:
      let overspend = snapshots.first { $0.budgetID == request.budgetID }?.forecast?.overspend ?? 0
      let amount = Money.format(overspend,
                                currencyCode: AppBaseCurrency.code(in: defaults),
                                showsCents: defaults.object(forKey: "showCents") as? Bool ?? true,
                                locale: .appLocale)
      content.title = String.appLocalized("Budget overspend forecast")
      content.body = String.appFormatted("At this pace you will overspend by %@", amount)
    }
    center.add(UNNotificationRequest(identifier: "budget-alert|\(request.dedupeKey)",
                                     content: content, trigger: nil))
  }
}
