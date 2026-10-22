//
//  HomeView+DeepLink.swift
//  smartbud
//
//  `smartbud://` URL handling: adding a transaction from an automation and
//  replying through x-callback-url. Parsing lives in `DeepLinkRequest`; this
//  file only maps a request onto the view models.
//

import Foundation
import SwiftUI

extension HomeView {

    /// Handles the `add` and `open` routes. Returns `false` when the URL is
    /// not ours (or belongs to a route another view already owns, such as
    /// search focus), so the caller can fall through to the older handlers.
    @discardableResult
    func handleDeepLink(_ url: URL) -> Bool {
        guard let request = DeepLinkRequest(url: url) else { return false }

        switch request.action {
        case .add:
            // Writing while the privacy lock is up would let a shortcut put
            // data in a ledger the user has explicitly hidden.
            guard !appLockVM.isAppLockEnabled || appLockVM.isAppUnLocked else {
                fireCallback(request.callbackError,
                             items: [URLQueryItem(name: "error", value: "app_locked")])
                return true
            }
            performDeepLinkAdd(request)
            return true
        case .open:
            if let tab = request.tab { currentTab = tab }
            fireCallback(request.callbackSuccess,
                         items: [URLQueryItem(name: "opened", value: request.tab ?? "")])
            return true
        case .search:
            currentTab = "Log"
            return false
        }
    }

    private func performDeepLinkAdd(_ request: DeepLinkRequest) {
        guard let amount = request.amount else {
            fireCallback(request.callbackError,
                         items: [URLQueryItem(name: "error", value: "invalid_amount")])
            return
        }

        categoryVM.load()
        accountVM.load()

        let income = request.isIncome
        let pool = income ? categoryVM.incomeCategories : categoryVM.expenseCategories
        let category = request.categoryName.flatMap { name in
            pool.first { $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame }
                ?? pool.first { $0.name.localizedStandardContains(name) }
        }
        let account = resolveAccount(request.accountHint)
        let note = request.note.isEmpty ? (category?.wrappedName ?? "") : request.note

        let transaction = transactionVM.create(TransactionEdit(
            note: note,
            category: category,
            account: account,
            income: income,
            amount: amount,
            date: request.date,
            repeatType: 0,
            repeatCoefficient: 0,
            discount: request.discount,
            reimbursable: request.isReimbursable && !income
        ))

        // The insights screen keeps a snapshot of the totals, and no view
        // transition happens here to refresh it (unlike closing the entry
        // form), so refresh explicitly.
        insightsVM.refreshAll()

        fireCallback(request.callbackSuccess, items: [
            URLQueryItem(name: "id", value: transaction.id.uuidString),
            URLQueryItem(name: "amount", value: String(format: "%.2f", amount)),
            URLQueryItem(name: "date", value: ISO8601DateFormatter().string(from: transaction.wrappedDate))
        ])
    }

    /// Matches an account by name or uuid, falling back to the default one so
    /// an automation never has to know which account exists.
    private func resolveAccount(_ hint: String?) -> AccountModel? {
        guard let hint, !hint.isEmpty else {
            return accountVM.defaultAccount(lastUsedID: nil)
        }
        if let match = accountVM.accounts.first(where: {
            $0.id.uuidString.caseInsensitiveCompare(hint) == .orderedSame
        }) {
            return match
        }
        return accountVM.accounts.first {
            $0.name.localizedCaseInsensitiveCompare(hint) == .orderedSame
        } ?? accountVM.defaultAccount(lastUsedID: nil)
    }

    private func fireCallback(_ base: URL?, items: [URLQueryItem]) {
        guard let url = DeepLinkRequest.resultURL(base, items: items) else { return }
        openURL(url)
    }
}
