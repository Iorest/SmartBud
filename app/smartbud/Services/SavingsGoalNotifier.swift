//
//  SavingsGoalNotifier.swift
//  smartbud
//
//  One-shot local notification for a goal reaching its target. The decision
//  is pure (SavingsGoalPolicy.shouldNotify); this file only schedules it and
//  honours both the app-wide reminder switch and the per-goal switch.
//

import Foundation
import UserNotifications

enum SavingsGoalNotifier {
    private static func identifier(for goalID: UUID) -> String {
        "savings-goal.\(goalID.uuidString)"
    }

    /// Returns true when a request was actually added. The caller stamps
    /// `notifiedAt` only on true, so a denied authorization can be retried on
    /// the next edit instead of being silently lost.
    @discardableResult
    static func notifyIfNeeded(
        goal: SavingsGoalModel,
        progress: SavingsProgress,
        notificationsEnabled: Bool,
        center: UNUserNotificationCenter = .current()
    ) async -> Bool {
        guard notificationsEnabled,
              SavingsGoalPolicy.shouldNotify(goal: goal, progress: progress)
        else { return false }

        let content = UNMutableNotificationContent()
        content.title = String.appLocalized("Savings goal reached")
        content.body = String.appFormatted("You reached “%@”.", goal.name)
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: identifier(for: goal.id), content: content, trigger: nil)
        do {
            try await center.add(request)
            return true
        } catch {
            return false
        }
    }

    /// Called when a goal is deleted or its reminder is switched off, so a
    /// pending request cannot fire for a goal the user no longer tracks.
    static func cancel(goalID: UUID, center: UNUserNotificationCenter = .current()) {
        center.removePendingNotificationRequests(
            withIdentifiers: [identifier(for: goalID)])
    }
}
