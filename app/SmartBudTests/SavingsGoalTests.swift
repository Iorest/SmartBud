//
//  SavingsGoalTests.swift
//  SmartBudTests
//
//  Pure savings-goal money rules. Runs in the Linux harness as well as the
//  macOS suite: no SwiftData, no SwiftUI, no locale-dependent calendar.
//

import Testing
import Foundation

@Suite("Savings goals")
struct SavingsGoalTests {

    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func goal(
        target: Double = 1_000,
        saved: Double = 300,
        days: Int = 10
    ) -> SavingsGoalModel {
        var goal = SavingsGoalModel()
        goal.name = "Trip"
        goal.mode = .flexible
        goal.targetAmount = target
        goal.savedAmount = saved
        goal.startDate = now.addingTimeInterval(-86_400 * 10)
        goal.deadline = now.addingTimeInterval(86_400 * Double(days))
        return goal
    }

    @Test("Normal progress splits the remainder across the days left")
    func normalProgress() {
        let progress = SavingsGoalProgress.evaluate(goal: goal(), now: now)
        #expect(progress.state == .inProgress)
        #expect(Money.cents(progress.saved) == Money.cents(300))
        #expect(Money.cents(progress.remaining) == Money.cents(700))
        #expect(progress.daysRemaining == 10)
        #expect(Money.cents(progress.dailyNeed) == Money.cents(70))
        #expect(progress.ratio == 0.3)
    }

    @Test("Over-funding closes the ring and leaves nothing to save")
    func overAchieved() {
        let progress = SavingsGoalProgress.evaluate(
            goal: goal(target: 1_000, saved: 1_250), now: now)
        #expect(progress.state == .achieved)
        #expect(Money.cents(progress.remaining) == 0)
        #expect(progress.ratio == 1)
        #expect(Money.cents(progress.dailyNeed) == 0)
    }

    @Test("An overdue goal puts the whole remainder in today")
    func overdue() {
        let progress = SavingsGoalProgress.evaluate(
            goal: goal(saved: 300, days: -2), now: now)
        #expect(progress.state == .overdue)
        #expect(progress.daysRemaining == 0)
        #expect(Money.cents(progress.dailyNeed) == Money.cents(700))
    }

    @Test("Reducing the target below what is saved completes the goal once")
    func targetReduced() {
        let reduced = goal(target: 600, saved: 800)
        let progress = SavingsGoalProgress.evaluate(goal: reduced, now: now)
        #expect(progress.state == .achieved)
        #expect(Money.cents(progress.remaining) == 0)

        // A new goal that starts complete is stamped, not alerted.
        #expect(!SavingsGoalPolicy.shouldNotify(goal: reduced, progress: progress))
        let marked = SavingsGoalPolicy.markingAchieved(reduced, progress: progress, now: now)
        #expect(marked.achievedAt == now)
        #expect(SavingsGoalPolicy.shouldNotify(goal: marked, progress: progress))

        var notified = marked
        notified.notifiedAt = now
        #expect(!SavingsGoalPolicy.shouldNotify(goal: notified, progress: progress))
        notified.notifyOnAchievement = false
        notified.notifiedAt = nil
        #expect(!SavingsGoalPolicy.shouldNotify(goal: notified, progress: progress))
    }

    @Test("Fixed-amount mode derives the target and the deadline from the plan")
    func fixedAmountMode() {
        var plan = goal()
        plan.mode = .fixedAmount
        plan.amountPerPeriod = 200
        plan.periods = 6
        plan.periodMonths = 2
        plan.startDate = now
        #expect(plan.effectiveTarget == 1_200)

        let deadline = SavingsGoalSchedule.deadline(from: now, months: 12)
        #expect(plan.effectiveDeadline == deadline)
        let progress = SavingsGoalProgress.evaluate(goal: plan, now: now)
        #expect(progress.state == .inProgress)
        #expect(Money.cents(progress.remaining) == Money.cents(900))
    }

    @Test("Balance-linked goals read the card, not the manual counter")
    func balanceLinked() {
        var linked = goal(saved: 0)
        linked.useAccountBalance = true
        linked.linkedAccountID = UUID()
        let progress = SavingsGoalProgress.evaluate(
            goal: linked, accountBalance: 450, now: now)
        #expect(Money.cents(progress.saved) == Money.cents(450))
        #expect(Money.cents(progress.remaining) == Money.cents(550))
        // With no balance supplied the counter stays at zero; the card is
        // the only source of truth in this mode.
        let withoutBalance = SavingsGoalProgress.evaluate(goal: linked, now: now)
        #expect(Money.cents(withoutBalance.saved) == 0)
        #expect(Money.cents(withoutBalance.remaining) == Money.cents(1_000))
    }

    @Test("Validation rejects an empty name and a zero target in each mode")
    func validation() {
        var candidate = goal()
        #expect(SavingsGoalPolicy.isValid(candidate))
        candidate.name = "  "
        #expect(!SavingsGoalPolicy.isValid(candidate))
        candidate = goal(target: 0)
        #expect(!SavingsGoalPolicy.isValid(candidate))

        candidate = goal()
        candidate.mode = .fixedAmount
        candidate.amountPerPeriod = 100
        candidate.periods = 3
        candidate.periodMonths = 1
        #expect(SavingsGoalPolicy.isValid(candidate))
        candidate.periods = 0
        #expect(!SavingsGoalPolicy.isValid(candidate))
    }

    @Test("Backup DTO round trip keeps every stored field")
    func dtoRoundTrip() throws {
        var original = goal()
        original.bookID = UUID()
        original.icon = "house"
        original.mode = .fixedAmount
        original.periodMonths = 3
        original.periods = 4
        original.amountPerPeriod = 250
        original.linkedAccountID = UUID()
        original.useAccountBalance = true
        original.notifyOnAchievement = false
        original.notifiedAt = now
        original.achievedAt = now

        let dto = ExportSchema.SavingsGoalDTO(model: original)
        let data = try JSONEncoder().encode([dto])
        let decoded = try JSONDecoder().decode([ExportSchema.SavingsGoalDTO].self, from: data)
        #expect(decoded.first?.model == original)
    }
}
