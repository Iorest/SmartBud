//
//  AccountViewModel.swift
//  smartbud
//
//  Accounts group transactions by where the money lives. Balances are derived
//  from the opening balance plus every linked transaction, so nothing can go
//  stale the way a stored running total would.
//

import Foundation
import Observation
import SwiftData
import SwiftUI

/// Values captured by the account editor.
struct AccountDraft {
    let name: String
    let emoji: String
    let colour: String
    let kind: AccountKind
    let currencyCode: String
    let openingBalance: Double
    let creditLimit: Double?
    let statementDay: Int?
    let dueDay: Int?
}

/// The three account types the editor offers. Stored as `Int` on the model so
/// the schema stays backwards compatible.
enum AccountKind: Int, CaseIterable, Identifiable {
    case cash = 0
    case debit = 1
    case credit = 2

    var id: Int { rawValue }

    var titleKey: String {
        switch self {
        case .cash: return "Cash"
        case .debit: return "Debit Card"
        case .credit: return "Credit Card"
        }
    }

    var symbol: String {
        switch self {
        case .cash: return "banknote"
        case .debit: return "creditcard"
        case .credit: return "creditcard.fill"
        }
    }
}

@MainActor
@Observable
final class AccountViewModel {
    static let shared = AccountViewModel()
    private let repo = DataRepository.shared

    var accounts: [AccountModel] = []
    var transfers: [TransferModel] = []

    func load() {
        // Balances and totals convert with the user's rates, so refresh them
        // alongside the accounts (cheap: one small fetch).
        CurrencyRateStore.shared.load()
        // Only the active ledger's rows belong on this screen. Transfers have
        // no book column; `BookScope` resolves theirs through the accounts.
        let selected = BookState.shared.currentID
        accounts = BookScope.scoped(
            repo.fetch(AccountModel.self, sort: [SortDescriptor(\.order)]),
            \.bookID, selected: selected)
        transfers = repo.fetch(TransferModel.self, sort: [SortDescriptor(\.date, order: .reverse)])
            .filter { BookScope.matches($0, selected: selected) }
    }

    var visibleAccounts: [AccountModel] {
        accounts.filter { !$0.hidden && !$0.archived }
    }

    /// Archived accounts are out of the daily list and the total, but their
    /// history stays intact.
    var archivedAccounts: [AccountModel] {
        accounts.filter(\.archived)
    }

    /// Hidden accounts were previously unreachable: the row that could show
    /// them again was itself filtered out. They get their own section so the
    /// action is reversible.
    var hiddenAccounts: [AccountModel] {
        accounts.filter { $0.hidden && !$0.archived }
    }

    private var netWorthEntries: [NetWorth.Account] {
        accounts.map { account in
            NetWorth.Account(
                balance: CurrencyRateStore.shared.convertToBase(
                    balance(for: account), from: account.resolvedCurrencyCode),
                included: !account.hidden && !account.archived
            )
        }
    }

    /// Positive balances across every visible account, including a credit
    /// card's overpayment. All three figures share the same cent rounding.
    var totalAssets: Double { NetWorth.assets(netWorthEntries) }

    /// Outstanding debt: the magnitude of negative visible balances.
    var totalDebt: Double { NetWorth.debt(netWorthEntries) }

    var netWorth: Double { NetWorth.total(netWorthEntries) }

    /// The account-list header keeps its old name; the number is net worth
    /// (assets minus debt) rather than a raw sum of all balances.
    var totalBalance: Double { netWorth }

    func balance(for account: AccountModel) -> Double {
        AccountBalance.current(
            opening: account.openingBalance,
            transactions: (account.transactions ?? [])
                .filter { BookScope.matches($0.bookID, selected: BookState.shared.currentID) }
                .map {
                    (amount: $0.amount, income: $0.income, isRefund: $0.isRefund)
                },
            transfersIn: (account.incomingTransfers ?? [])
                .filter { BookScope.matches($0, selected: BookState.shared.currentID) }
                .reduce(0) { $0 + $1.receivedAmount },
            transfersOut: (account.outgoingTransfers ?? [])
                .filter { BookScope.matches($0, selected: BookState.shared.currentID) }
                .reduce(0) { $0 + $1.outgoingTotal }
        )
    }

    /// Used / available credit and the amount due in the current statement
    /// cycle. Nil when this is not a card or no limit is configured — an
    /// unlimited card has no over-limit warning to show.
    func creditUsage(for account: AccountModel) -> CreditUsage? {
        guard CreditCard.isCredit(kind: account.kind) else { return nil }
        let terms = CreditCard.sanitized(limit: account.creditLimit,
                                         statementDay: account.statementDay,
                                         dueDay: account.dueDay,
                                         kind: account.kind)
        guard let limit = terms.limit else { return nil }

        var cycleSpend = 0.0
        if let cycle = CreditCard.cycle(statementDay: terms.statementDay, at: .now) {
            let now = Date.now
            let rows = (account.transactions ?? []).filter { txn in
                guard let date = txn.date else { return false }
                return BookScope.matches(txn.bookID, selected: BookState.shared.currentID)
                    && date >= cycle.start && date < cycle.end && date <= now
                    && !txn.adjustment
                    && (txn.isRefund || (!txn.income && txn.refundOf == nil))
            }
            cycleSpend = rows.reduce(0) { $0 + ($1.isRefund ? -$1.amount : $1.amount) }
        }
        return CreditCard.usage(limit: limit, balance: balance(for: account),
                                cycleSpend: cycleSpend)
    }

    /// Transfers touching `account`, newest first.
    func transfers(for account: AccountModel) -> [TransferModel] {
        transfers.filter { $0.source?.id == account.id || $0.destination?.id == account.id }
    }

    @discardableResult
    func createTransfer(
        source: AccountModel,
        destination: AccountModel,
        amount: Double,
        destinationAmount: Double = 0,
        fee: Double = 0,
        date: Date,
        note: String
    ) -> TransferModel? {
        // Both ends must be in the active ledger, or the fee row and the
        // transfer could land in different books.
        guard BookScope.matches(source.bookID, selected: BookState.shared.currentID),
              BookScope.matches(destination.bookID, selected: BookState.shared.currentID)
        else { return nil }
        guard source.id != destination.id, amount > 0, amount.isFinite else { return nil }
        guard fee >= 0, fee.isFinite else { return nil }

        // Same currency keeps the legacy shape (destinationAmount left at 0);
        // crossing currencies records what actually landed in the target.
        let received = destination.resolvedCurrencyCode == source.resolvedCurrencyCode
            ? 0
            : destinationAmount
        if received != 0, !(received > 0 && received.isFinite) { return nil }

        let transfer = TransferModel(
            amount: amount,
            destinationAmount: received,
            fee: fee,
            date: date,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : note,
            source: source,
            destination: destination
        )
        repo.insert(transfer)
        // The fee is real money out, so it becomes its own expense row instead
        // of disappearing into the transfer.
        TransferFeeLedger.recordFee(
            for: transfer, in: repo.context,
            baseAmount: CurrencyRateStore.shared.convertToBase(
                fee, from: source.resolvedCurrencyCode))
        repo.save()
        load()
        return transfer
    }

    func deleteTransfer(_ transfer: TransferModel) {
        TransferFeeLedger.deleteFeeRows(for: transfer, in: repo.context)
        repo.delete(transfer)
        repo.save()
        load()
    }

    @discardableResult
    func create(_ draft: AccountDraft) -> AccountModel {
        let terms = CreditCard.sanitized(limit: draft.creditLimit,
                                         statementDay: draft.statementDay,
                                         dueDay: draft.dueDay,
                                         kind: draft.kind.rawValue)
        let account = AccountModel(
            name: draft.name,
            emoji: draft.emoji,
            colour: draft.colour,
            kind: draft.kind.rawValue,
            currencyCode: draft.currencyCode,
            openingBalance: draft.openingBalance,
            order: (accounts.last?.order ?? 0) + 1,
            bookID: BookState.shared.currentID,
            creditLimit: terms.limit,
            statementDay: terms.statementDay,
            dueDay: terms.dueDay
        )
        repo.insert(account)
        repo.save()
        load()
        return account
    }

    func update(_ account: AccountModel, with draft: AccountDraft) {
        let terms = CreditCard.sanitized(limit: draft.creditLimit,
                                         statementDay: draft.statementDay,
                                         dueDay: draft.dueDay,
                                         kind: draft.kind.rawValue)
        account.name = draft.name
        account.emoji = draft.emoji
        account.colour = draft.colour
        account.kind = draft.kind.rawValue
        account.currencyCode = draft.currencyCode
        account.openingBalance = draft.openingBalance
        account.creditLimit = terms.limit
        account.statementDay = terms.statementDay
        account.dueDay = terms.dueDay
        repo.save()
        load()
    }

    /// Deleting an account keeps its transactions and just clears the link,
    /// the same rule categories use.
    func delete(_ account: AccountModel) {
        for txn in account.transactions ?? [] {
            txn.account = nil
        }
        // A transfer needs both ends to stay meaningful, so it goes with
        // whichever account is deleted. Its fee row is part of that transfer:
        // leaving it behind would keep charging spend for a move that no
        // longer exists and would orphan it from any account.
        for transfer in (account.outgoingTransfers ?? []) + (account.incomingTransfers ?? []) {
            TransferFeeLedger.deleteFeeRows(for: transfer, in: repo.context)
            repo.delete(transfer)
        }
        repo.delete(account)
        repo.save()
        load()
    }

    func setHidden(_ hidden: Bool, for account: AccountModel) {
        account.hidden = hidden
        repo.save()
        load()
    }

    func setArchived(_ archived: Bool, for account: AccountModel) {
        account.archived = archived
        repo.save()
        load()
    }

    /// Corrects the account to `target` with a dedicated adjustment row, so
    /// the opening balance (and the history behind it) is never rewritten.
    @discardableResult
    func adjustBalance(_ account: AccountModel, to target: Double, date: Date = .now) -> TransactionModel? {
        guard target.isFinite else { return nil }
        // The correction row stores a base-currency amount too. Without a rate
        // that number would be a 1:1 guess, so the adjustment is refused — the
        // sheet already says which screen fixes it.
        guard !CurrencyRateStore.shared.needsRate(for: account.resolvedCurrencyCode) else {
            return nil
        }
        guard let delta = AccountBalance.adjustmentDelta(
            target: target, current: balance(for: account)) else { return nil }

        let transaction = TransactionModel(
            note: String.appLocalized("Balance Adjustment"),
            account: account,
            baseAmount: CurrencyRateStore.shared.convertToBase(
                abs(delta), from: account.resolvedCurrencyCode),
            income: delta > 0,
            amount: abs(delta),
            date: date,
            adjustment: true,
            bookID: BookState.shared.currentID
        )
        repo.insert(transaction)
        repo.save()
        load()
        return transaction
    }

    /// Default for a new transaction: the account used last, otherwise the
    /// first visible one. An archived account is never auto-selected — it is
    /// out of the daily flow, so a new entry must not land there by accident.
    func defaultAccount(lastUsedID: String?) -> AccountModel? {
        if let lastUsedID,
           let match = accounts.first(where: { $0.id.uuidString == lastUsedID }),
           BookScope.matches(match.bookID, selected: BookState.shared.currentID),
           !match.archived, !match.hidden {
            return match
        }
        return visibleAccounts.first
    }
}

extension AccountModel {
    @Transient var wrappedName: String { name }
    @Transient var wrappedEmoji: String { emoji }
    @Transient var wrappedColour: String { colour }
    /// A linked transaction can still belong to another ledger (e.g. after an
    /// import), so the relationship is scoped here too. `BookSelection` reads
    /// the same persisted value `BookState` publishes on the main actor.
    @Transient var allTransactions: [TransactionModel] {
        BookScope.scoped((transactions ?? []).sorted { $0.wrappedDate < $1.wrappedDate },
                         \.bookID, selected: BookSelection.current())
    }
}
