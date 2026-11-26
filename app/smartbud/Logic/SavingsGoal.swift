//
//  SavingsGoal.swift
//  smartbud
//
//  Savings goals: the money rules and the persisted shape. Kept Foundation-
//  only (like InstallmentPolicy) so progress can be tested on Linux and the
//  backup DTO can share the stored fields without a SwiftData dependency.
//
//  Goals never change an account balance by themselves. A deposit either
//  increments `savedAmount` (manual tracking) or writes an ordinary transfer
//  into the linked savings account (balance tracking); both paths are handled
//  by SavingsGoalViewModel, not by this file.
//

import Foundation

/// iCost's two savings modes: a fixed amount repeated over a number of
/// periods, or one target between a start and an end date.
enum SavingsGoalMode: Int, Codable, Equatable {
    case fixedAmount = 0
    case flexible = 1
}

struct SavingsGoalModel: Codable, Equatable, Identifiable {
    var id: UUID = UUID()
    /// Ledger the goal belongs to. Persisted per book; nil in old backups.
    var bookID: UUID? = nil
    var name: String = ""
    /// SF Symbol name chosen by the user. Empty falls back to the default.
    var icon: String = "target"
    var mode: SavingsGoalMode = .flexible

    /// Flexible mode: the amount to reach.
    var targetAmount: Double = 0
    /// Flexible mode start; fixed mode first period anchor.
    var startDate: Date = .now
    /// Flexible mode deadline.
    var deadline: Date = .now

    /// Fixed mode: months per period (1...12).
    var periodMonths: Int = 1
    /// Fixed mode: number of periods.
    var periods: Int = 1
    /// Fixed mode: amount saved each period.
    var amountPerPeriod: Double = 0

    /// Manual deposits, in the base currency.
    var savedAmount: Double = 0
    /// Linked "savings card". nil means an independent goal.
    var linkedAccountID: UUID? = nil
    /// When true the linked account's balance is the saved amount; the goal's
    /// own counter is then only a record of manual deposits.
    var useAccountBalance: Bool = false

    var notifyOnAchievement: Bool = true
    /// Set when the one-shot achievement notification was scheduled.
    var notifiedAt: Date? = nil
    /// Set when the goal first reached its target (survives later edits).
    var achievedAt: Date? = nil
    var dateCreated: Date = .now

    /// The amount that counts as "done". Fixed mode derives it from the
    /// period plan so editing a period never needs a second target field.
    var effectiveTarget: Double {
        switch mode {
        case .fixedAmount:
            return Money.double(Money.cents(amountPerPeriod) * Decimal(max(0, periods)))
        case .flexible:
            return targetAmount
        }
    }

    /// Fixed mode ends after `periods × periodMonths`; flexible mode uses the
    /// user's deadline. A fixed plan with no periods ends on its start date.
    var effectiveDeadline: Date {
        switch mode {
        case .fixedAmount:
            return SavingsGoalSchedule.deadline(
                from: startDate, months: periodMonths * max(0, periods))
        case .flexible:
            return deadline
        }
    }
}

/// Date maths kept separate so progress never depends on the device calendar
/// and tests use the same UTC Gregorian rules on every machine.
enum SavingsGoalSchedule {
    static let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        return cal
    }()

    static func deadline(from start: Date, months: Int) -> Date {
        guard months > 0 else { return start }
        return calendar.date(byAdding: .month, value: months, to: start) ?? start
    }

    /// Whole days left, clamped at zero. Ceil keeps a deadline a few minutes
    /// away at "1 day" instead of silently showing "0" before it passes.
    static func daysLeft(from now: Date, to deadline: Date) -> Int {
        let seconds = deadline.timeIntervalSince(now)
        guard seconds.isFinite else { return 0 }
        return max(0, Int(ceil(seconds / 86_400)))
    }
}

struct SavingsProgress: Equatable {
    enum State: String, Codable {
        case inProgress
        case achieved
        case overdue
    }

    var saved: Double
    var target: Double
    var remaining: Double
    /// Ring fraction in 0...1; a fully funded goal is exactly 1.
    var ratio: Double
    var daysRemaining: Int
    /// What must be set aside each remaining day to finish on time. When the
    /// deadline has passed, the whole remainder is due today.
    var dailyNeed: Double
    var state: State
}

enum SavingsGoalProgress {
    static func evaluate(
        goal: SavingsGoalModel,
        accountBalance: Double? = nil,
        now: Date = .now
    ) -> SavingsProgress {
        let target = max(0, goal.effectiveTarget.isFinite ? goal.effectiveTarget : 0)
        let rawSaved = goal.useAccountBalance
            ? (accountBalance ?? 0)
            : goal.savedAmount
        let saved = max(0, rawSaved.isFinite ? rawSaved : 0)
        let days = SavingsGoalSchedule.daysLeft(
            from: now, to: goal.effectiveDeadline)

        let achieved = target > 0 && Money.cents(saved) >= Money.cents(target)
        let state: SavingsProgress.State = achieved
            ? .achieved
            : (days == 0 ? .overdue : .inProgress)
        let remainder = achieved ? 0 : Money.double(Money.cents(target) - Money.cents(saved))

        return SavingsProgress(
            saved: saved,
            target: target,
            remaining: remainder,
            ratio: target > 0 ? min(1, max(0, saved / target)) : 0,
            daysRemaining: days,
            dailyNeed: achieved ? 0 : Money.double(
                Money.cents(remainder) / Decimal(max(1, days))),
            state: state
        )
    }
}

enum SavingsGoalPolicy {
    /// Inputs that can be saved. A goal must have a name, a positive target
    /// and (in fixed mode) a positive per-period amount with at least one
    /// period. Deadlines in the past are allowed: those are overdue goals.
    static func isValid(_ goal: SavingsGoalModel) -> Bool {
        guard !goal.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }
        switch goal.mode {
        case .fixedAmount:
            return goal.amountPerPeriod.isFinite && goal.amountPerPeriod > 0
                && goal.periods > 0 && (1...12).contains(goal.periodMonths)
        case .flexible:
            return goal.targetAmount.isFinite && goal.targetAmount > 0
        }
    }

    /// Exactly one local notification per goal: never for a disabled goal,
    /// never twice, and only after the goal actually reached its target.
    static func shouldNotify(
        goal: SavingsGoalModel,
        progress: SavingsProgress,
        now: Date = .now
    ) -> Bool {
        guard goal.notifyOnAchievement, goal.notifiedAt == nil,
              progress.state == .achieved else { return false }
        // A goal that was already complete when first created is not a
        // "reached" event; only record it, do not alert the user.
        return goal.achievedAt != nil
    }

    /// Stamps the goal when progress first reaches the target. Called after
    /// every write so a later target reduction is also recognised.
    static func markingAchieved(
        _ goal: SavingsGoalModel,
        progress: SavingsProgress,
        now: Date = .now
    ) -> SavingsGoalModel {
        var copy = goal
        if progress.state == .achieved && copy.achievedAt == nil {
            copy.achievedAt = now
        }
        return copy
    }
}
