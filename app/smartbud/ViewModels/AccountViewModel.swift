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
        accounts = repo.fetch(AccountModel.self, sort: [SortDescriptor(\.order)])
        transfers = repo.fetch(TransferModel.self, sort: [SortDescriptor(\.date, order: .reverse)])
    }

    var visibleAccounts: [AccountModel] {
        accounts.filter { !$0.hidden }
    }

    /// Sum of every visible account, the number a "net worth" header shows.
    /// Sum of visible accounts converted to the app's base currency, so a
    /// mixed-currency list still yields one meaningful number.
    var totalBalance: Double {
        visibleAccounts.reduce(0) { total, account in
            total + CurrencyRateStore.shared.convertToBase(
                balance(for: account), from: account.resolvedCurrencyCode)
        }
    }

    func balance(for account: AccountModel) -> Double {
        AccountBalance.current(
            opening: account.openingBalance,
            transactions: (account.transactions ?? []).map { ($0.amount, $0.income) },
            transfersIn: (account.incomingTransfers ?? []).reduce(0) { $0 + $1.amount },
            transfersOut: (account.outgoingTransfers ?? []).reduce(0) { $0 + $1.amount }
        )
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
        date: Date,
        note: String
    ) -> TransferModel? {
        guard source.id != destination.id, amount > 0, amount.isFinite else { return nil }
        let transfer = TransferModel(
            amount: amount,
            date: date,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : note,
            source: source,
            destination: destination
        )
        repo.insert(transfer)
        repo.save()
        load()
        return transfer
    }

    func deleteTransfer(_ transfer: TransferModel) {
        repo.delete(transfer)
        repo.save()
        load()
    }

    @discardableResult
    func create(_ draft: AccountDraft) -> AccountModel {
        let account = AccountModel(
            name: draft.name,
            emoji: draft.emoji,
            colour: draft.colour,
            kind: draft.kind.rawValue,
            currencyCode: draft.currencyCode,
            openingBalance: draft.openingBalance,
            order: (accounts.last?.order ?? 0) + 1
        )
        repo.insert(account)
        repo.save()
        load()
        return account
    }

    func update(_ account: AccountModel, with draft: AccountDraft) {
        account.name = draft.name
        account.emoji = draft.emoji
        account.colour = draft.colour
        account.kind = draft.kind.rawValue
        account.currencyCode = draft.currencyCode
        account.openingBalance = draft.openingBalance
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
        // whichever account is deleted.
        for transfer in (account.outgoingTransfers ?? []) + (account.incomingTransfers ?? []) {
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

    /// Default for a new transaction: the account used last, otherwise the
    /// first visible one.
    func defaultAccount(lastUsedID: String?) -> AccountModel? {
        if let lastUsedID, let match = accounts.first(where: { $0.id.uuidString == lastUsedID }) {
            return match
        }
        return visibleAccounts.first
    }
}
