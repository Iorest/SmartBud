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

    /// Opens the entry sheet, but never above the privacy lock. A request that
    /// arrives while locked is remembered and replayed after unlocking, so a
    /// widget tap is not silently dropped.
    func requestNewTransaction() {
        if appLockVM.isAppLockEnabled && !appLockVM.isAppUnLocked {
            pendingAddAfterUnlock = true
            return
        }
        addTransaction = true
    }

    /// Closes every presentation owned by this screen. `AppLockView` lives in
    /// the HomeView ZStack, but a `fullScreenCover` sits above it, so a form
    /// left open when the app locks stayed interactive over the lock.
    func closePresentedScreens() {
        addTransaction = false
        transactionManager.toEdit = nil
        transactionManager.showPopup = false
        transactionManager.toDelete = nil
    }

    /// Handles the `add` and `open` routes. Returns `false` when the URL is
    /// not ours (or belongs to a route another view already owns, such as
    /// search focus), so the caller can fall through to the older handlers.
    @discardableResult
    func handleDeepLink(_ url: URL) -> Bool {
        guard let request = DeepLinkRequest(url: url) else { return false }

        // A widget link carries the book it was rendered for. Validate the id
        // before switching so a stale link cannot strand the user in an empty
        // ledger; an unknown id is ignored and the current book is kept.
        // Archived books stay valid because their data must remain readable.
        if let requested = request.bookID,
           DataRepository.shared.fetch(BookModel.self).contains(where: { $0.id == requested }) {
            BookState.shared.reloadBooks()
            BookState.shared.select(requested)
        }

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
            // Read-only, so it is allowed while locked. Carry the query and
            // ask the log screen to focus, instead of just switching tabs and
            // leaving the field empty.
            currentTab = "Log"
            launchSearchQuery = request.searchQuery
            launchSearch.toggle()
            return true
        }
    }

    private func performDeepLinkAdd(_ request: DeepLinkRequest) {
        guard let amount = request.amount else {
            fireCallback(request.callbackError,
                         items: [URLQueryItem(name: "error", value: "invalid_amount")])
            return
        }
        guard !request.dateIsInvalid else {
            fireCallback(request.callbackError,
                         items: [URLQueryItem(name: "error", value: "invalid_date")])
            return
        }

        categoryVM.load()
        accountVM.load()

        let selected = BookState.shared.currentID
        let income = request.isIncome
        let pool = BookScope.scoped(
            income ? categoryVM.incomeCategories : categoryVM.expenseCategories,
            \.bookID, selected: selected)
        let category = request.categoryName.flatMap { name in
            pool.first { $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame }
                ?? pool.first { $0.name.localizedStandardContains(name) }
        }
        let account = resolveAccount(request.accountHint, selected: selected)
        let note = request.note.isEmpty ? (category?.wrappedName ?? "") : request.note

        // Same rule as the entry form: no rate means no 1:1 guess frozen into
        // `baseAmount`. An automation gets a code it can act on instead of a
        // transaction that quietly distorts the totals.
        if let account,
           CurrencyRateStore.shared.needsRate(for: account.resolvedCurrencyCode) {
            fireCallback(request.callbackError,
                         items: [URLQueryItem(name: "error", value: "missing_rate")])
            return
        }

        guard let transaction = transactionVM.create(TransactionEdit(
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
        )) else {
            // The store refused the write and rolled the row back; an
            // automation asking over x-callback must not be told it landed.
            fireCallback(request.callbackError,
                         items: [URLQueryItem(name: "error", value: "save_failed")])
            return
        }

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
    private func resolveAccount(_ hint: String?, selected: UUID) -> AccountModel? {
        // The view models are already book-scoped; this second pass keeps a
        // saved `account=` hint from another book from becoming a cross-book
        // write if a cached list was populated before a switch.
        let candidates = BookScope.scoped(accountVM.accounts, \.bookID, selected: selected)
        let fallback = accountVM.defaultAccount(lastUsedID: nil).flatMap { account in
            candidates.first { $0.id == account.id }
        }
        guard let hint, !hint.isEmpty else { return fallback }
        if let match = candidates.first(where: {
            $0.id.uuidString.caseInsensitiveCompare(hint) == .orderedSame
        }) {
            return match
        }
        return candidates.first {
            $0.name.localizedCaseInsensitiveCompare(hint) == .orderedSame
        } ?? fallback
    }

    private func fireCallback(_ base: URL?, items: [URLQueryItem]) {
        guard let url = DeepLinkRequest.resultURL(base, items: items) else { return }
        openURL(url)
    }
}
