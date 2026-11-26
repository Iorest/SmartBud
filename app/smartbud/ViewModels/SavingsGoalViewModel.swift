//
//  SavingsGoalViewModel.swift
//  smartbud
//
//  Goal CRUD, progress and deposits. Deposits either write an ordinary
//  transfer into the linked savings account (money actually moves) or only
//  advance the goal's own counter (manual tracking). Nothing here adds an
//  expense, so the ledger's spend and net-worth rules stay untouched.
//

import Foundation
import Observation
import SwiftData
import SwiftUI

@MainActor
@Observable
final class SavingsGoalViewModel {
    private let repo = DataRepository.shared
    private let accountVM = AccountViewModel.shared

    var goals: [SavingsGoalModel] = []
    /// Validation error shown in the editor/deposit sheet.
    var message: String?

    func load() {
        accountVM.load()
        goals = SavingsGoalStore.all(in: repo.context)
            .filter { BookScope.matches($0.bookID, selected: BookState.shared.currentID) }
            .sorted {
                ($0.dateCreated, $0.id.uuidString) < ($1.dateCreated, $1.id.uuidString)
            }
    }

    var accounts: [AccountModel] { accountVM.visibleAccounts }

    func account(for goal: SavingsGoalModel) -> AccountModel? {
        guard let id = goal.linkedAccountID else { return nil }
        return accountVM.accounts.first { $0.id == id }
    }

    func balance(for goal: SavingsGoalModel) -> Double? {
        guard let account = account(for: goal) else { return nil }
        return accountVM.balance(for: account)
    }

    func progress(for goal: SavingsGoalModel, now: Date = .now) -> SavingsProgress {
        SavingsGoalProgress.evaluate(goal: goal, accountBalance: balance(for: goal), now: now)
    }

    /// Creates or updates a goal. A goal that is already complete when first
    /// created is stamped as notified: showing a "reached" alert for a target
    /// the user just typed in would be noise. Reaching the target through a
    /// later edit (for example reducing the target) is a real event.
    @discardableResult
    func upsert(_ goal: SavingsGoalModel, notificationsEnabled: Bool) async -> Bool {
        message = nil
        guard SavingsGoalPolicy.isValid(goal) else {
            message = String.appLocalized("Enter a name and a target greater than zero.")
            return false
        }
        var copy = goal
        copy.bookID = BookState.shared.currentID
        let isNew = !goals.contains { $0.id == copy.id }
        var result = SavingsGoalProgress.evaluate(
            goal: copy, accountBalance: balance(for: copy))
        copy = SavingsGoalPolicy.markingAchieved(copy, progress: result)
        if isNew, result.state == .achieved { copy.notifiedAt = .now }

        SavingsGoalStore.upsert(copy, in: repo.context)
        guard repo.save() else {
            message = String.appLocalized("无法保存更改，请稍后重试。")
            return false
        }
        load()

        if !isNew {
            result = SavingsGoalProgress.evaluate(goal: copy, accountBalance: balance(for: copy))
            await fireNotification(for: copy, progress: result, enabled: notificationsEnabled)
        }
        return true
    }

    /// "Save again" / iCost's 再次存入. With a linked card and a source
    /// account, the money is written as a same-currency transfer; in balance
    /// mode that transfer is the saved amount and the counter is not touched.
    @discardableResult
    func deposit(
        _ amount: Double,
        into goal: SavingsGoalModel,
        from source: AccountModel?,
        notificationsEnabled: Bool
    ) async -> Bool {
        message = nil
        guard amount.isFinite, amount > 0, amount <= Money.maxAmount else {
            message = String.appLocalized("Enter an amount greater than zero.")
            return false
        }
        var copy = goal
        let destination = account(for: goal)
        // A chosen source or balance tracking both require a real transfer
        // into a real card. Without this guard the tap would be silently
        // discarded and the sheet would still close.
        if source != nil || copy.useAccountBalance {
            guard source != nil, destination != nil else {
                message = String.appLocalized(
                    "A deposit needs a source account and a linked card.")
                return false
            }
        }
        if let source, let destination {
            guard source.id != destination.id else {
                message = String.appLocalized("Pick two different accounts.")
                return false
            }
            guard source.resolvedCurrencyCode == destination.resolvedCurrencyCode else {
                message = String.appLocalized(
                    "A savings deposit must use the same currency as the goal's card.")
                return false
            }
            let transfer = TransferModel(
                amount: amount,
                date: .now,
                note: String.appFormatted("Savings deposit: %@", goal.name),
                source: source,
                destination: destination
            )
            repo.insert(transfer)
        }
        if !copy.useAccountBalance {
            copy.savedAmount = Money.double(Money.cents(copy.savedAmount) + Money.cents(amount))
        }
        var result = SavingsGoalProgress.evaluate(
            goal: copy, accountBalance: balance(for: copy))
        copy = SavingsGoalPolicy.markingAchieved(copy, progress: result)
        SavingsGoalStore.upsert(copy, in: repo.context)
        guard repo.save() else {
            message = String.appLocalized("无法保存更改，请稍后重试。")
            return false
        }
        load()

        result = SavingsGoalProgress.evaluate(goal: copy, accountBalance: balance(for: copy))
        await fireNotification(for: copy, progress: result, enabled: notificationsEnabled)
        return true
    }

    func remove(_ goal: SavingsGoalModel) {
        SavingsGoalStore.remove(id: goal.id, in: repo.context)
        repo.save()
        SavingsGoalNotifier.cancel(goalID: goal.id)
        load()
    }


    private func fireNotification(
        for goal: SavingsGoalModel,
        progress: SavingsProgress,
        enabled: Bool
    ) async {
        guard await SavingsGoalNotifier.notifyIfNeeded(
            goal: goal, progress: progress, notificationsEnabled: enabled) else { return }
        var copy = goal
        copy.notifiedAt = .now
        SavingsGoalStore.upsert(copy, in: repo.context)
        repo.save()
        load()
    }
}
