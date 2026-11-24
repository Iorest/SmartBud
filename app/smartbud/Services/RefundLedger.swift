//
//  RefundLedger.swift
//  smartbud
//
//  The refund half of an expense. A refund is its own row — money arriving in
//  an account — pointing at the purchase it gives back (`refundOf`). It is
//  never income, and the original expense stays untouched: the refunded total
//  is derived from the refund rows, so deleting one puts the full amount back
//  without a stored counter to repair.
//
//  Rules live in `RefundPolicy` (Foundation only, tested on Linux); this file
//  only fetches, mutates and cascades.
//

import Foundation
import SwiftData

@MainActor
enum RefundLedger {

    /// Every refund row in the store. `#Predicate` cannot compare an optional
    /// UUID inside the app's SwiftData build reliably, so the rows are
    /// filtered in memory — the refund set is small next to the ledger.
    static func allRefunds(in context: ModelContext) -> [TransactionModel] {
        let descriptor = FetchDescriptor<TransactionModel>(
            predicate: #Predicate { $0.refundOf != nil })
        return (try? context.fetch(descriptor)) ?? []
    }

    static func refunds(of original: TransactionModel, in context: ModelContext) -> [TransactionModel] {
        allRefunds(in: context).filter { $0.refundOf == original.id }
    }

    static func original(for refund: TransactionModel, in context: ModelContext) -> TransactionModel? {
        guard let originalID = refund.refundOf else { return nil }
        let descriptor = FetchDescriptor<TransactionModel>(
            predicate: #Predicate { $0.id == originalID })
        return (try? context.fetch(descriptor))?.first
    }

    /// Sum of the amounts already given back, in the original's currency.
    static func refundedTotal(for original: TransactionModel, in context: ModelContext) -> Double {
        let rows = refunds(of: original, in: context)
        return Money.double(Money.sum(rows.map(\.amount)))
    }

    /// How much of the original expense is still refundable.
    static func remaining(for original: TransactionModel, in context: ModelContext) -> Double {
        RefundPolicy.remaining(originalAmount: original.amount,
                               refunded: refundedTotal(for: original, in: context))
    }

    // MARK: - Writing

    /// Currency the original was recorded in. A refund has to arrive in that
    /// currency: its base amount is converted with the rate frozen on the
    /// original row, which only means something for the same currency.
    static func currency(of original: TransactionModel) -> String {
        currency(of: original.account)
    }

    /// Same rule as `AccountModel.resolvedCurrencyCode`, spelled out here so
    /// the ledger also compiles into the test target (which does not include
    /// the rate store). An empty code means the account follows the base
    /// currency.
    static func currency(of account: AccountModel?) -> String {
        guard let code = account?.currencyCode, !code.isEmpty else {
            return AppBaseCurrency.code
        }
        return code
    }

    /// Writes a refund row (not saved; the caller commits). The amount is in
    /// the original expense's currency, the base amount uses the original's
    /// frozen rate, and the category is copied so the refund reduces the same
    /// category's spend in the period the money arrived.
    static func refund(_ original: TransactionModel,
                       amount: Double,
                       date: Date,
                       account: AccountModel?,
                       note: String,
                       in context: ModelContext) -> Result<TransactionModel, RefundPolicy.Failure> {
        guard original.canBeRefunded else { return .failure(.notAnExpense) }
        guard currency(of: original) == currency(of: account) else {
            return .failure(.currencyMismatch)
        }
        let refunded = refundedTotal(for: original, in: context)
        if let failure = RefundPolicy.validate(
            amount: amount, date: date,
            originalAmount: original.amount, originalDate: original.wrappedDate,
            refunded: refunded
        ) {
            return .failure(failure)
        }
        guard let base = RefundPolicy.baseAmount(
            originalBaseAmount: original.wrappedBaseAmount,
            originalAmount: original.amount,
            refundAmount: amount
        ) else {
            return .failure(.nonPositiveAmount)
        }

        let name = original.wrappedNote.isEmpty ? original.wrappedCategoryName : original.wrappedNote
        // Derived rows stay in the original's ledger even if the active book
        // changed while the refund sheet was open.
        let row = TransactionModel(
            note: note.isEmpty ? String.appFormatted("Refund · %@", name) : note,
            category: original.category,
            account: account,
            baseAmount: base,
            income: false,
            amount: amount,
            date: date,
            refundOf: original.id,
            merchant: original.merchant,
            merchantKey: original.merchantKey,
            bookID: original.bookID
        )
        context.insert(row)
        return .success(row)
    }

    /// Changes an existing refund. `refundedTotal` excludes this row, so the
    /// edited amount is checked against what is still free.
    static func update(_ refund: TransactionModel,
                       amount: Double,
                       date: Date,
                       account: AccountModel?,
                       note: String,
                       in context: ModelContext) -> RefundPolicy.Failure? {
        guard let original = original(for: refund, in: context) else {
            return .notAnExpense
        }
        guard currency(of: original) == currency(of: account) else {
            return .currencyMismatch
        }
        let others = Money.double(Money.sum(
            refunds(of: original, in: context)
                .filter { $0.id != refund.id }
                .map(\.amount)))
        if let failure = RefundPolicy.validateEdit(
            amount: amount, date: date,
            originalAmount: original.amount, originalDate: original.wrappedDate,
            refundedExcludingSelf: others
        ) {
            return failure
        }
        guard let base = RefundPolicy.baseAmount(
            originalBaseAmount: original.wrappedBaseAmount,
            originalAmount: original.amount,
            refundAmount: amount
        ) else {
            return .nonPositiveAmount
        }

        refund.amount = amount
        refund.baseAmount = base
        refund.account = account
        refund.date = date
        if !note.isEmpty { refund.note = note }
        let calendar = Calendar(identifier: .gregorian)
        refund.day = calendar.date(bySettingHour: 0, minute: 0, second: 0, of: date) ?? date
        let comps = calendar.dateComponents([.month, .year], from: date)
        refund.month = calendar.date(from: comps) ?? date
        return nil
    }

    /// Called before deleting a row. A purchase takes its refunds with it —
    /// a refund pointing at a deleted row would be an orphan whose money came
    /// from nowhere. Deleting a refund row itself needs no cleanup: the
    /// original's remaining amount is derived.
    static func prepareForDeletion(of txn: TransactionModel, in context: ModelContext) {
        guard txn.refundOf == nil else { return }
        for row in refunds(of: txn, in: context) {
            context.delete(row)
        }
    }
}
