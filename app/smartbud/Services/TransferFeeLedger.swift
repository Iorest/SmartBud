//
//  TransferFeeLedger.swift
//  smartbud
//
//  A transfer fee is money you actually spent, so it is recorded as an expense
//  row on the sending account instead of being folded into the transfer. That
//  way it appears in the ledger, counts towards spend, budgets and the widgets,
//  and can be categorised — while the transfer itself stays a pure move.
//
//  The transfer keeps `fee` only for display ("you were charged 2.50"). The
//  balance comes from the expense row, so the two must never both be charged:
//  `TransferModel.outgoingTotal` is the amount alone.
//

import Foundation
import SwiftData

@MainActor
enum TransferFeeLedger {

    /// Category used for auto-recorded fees, created on first use.
    static let categoryNameKey = "Transfer Fee"

    static func feeRows(in context: ModelContext) -> [TransactionModel] {
        let descriptor = FetchDescriptor<TransactionModel>(
            predicate: #Predicate { $0.transferFeeOf != nil })
        return (try? context.fetch(descriptor)) ?? []
    }

    static func feeRow(for transfer: TransferModel, in context: ModelContext) -> TransactionModel? {
        feeRows(in: context).first { $0.transferFeeOf == transfer.id }
    }

    /// Writes the expense row for a transfer's fee. No-op when the fee is zero
    /// or the row already exists.
    /// `baseAmount` is the fee converted to the base currency at today's rate.
    /// Callers pass it in so this type stays free of the rate store (and can be
    /// tested without one); `nil` means the account is denominated in base.
    @discardableResult
    static func recordFee(for transfer: TransferModel, in context: ModelContext,
                          baseAmount: Double? = nil) -> TransactionModel? {
        guard transfer.fee > 0, transfer.fee.isFinite else { return nil }
        if let existing = feeRow(for: transfer, in: context) { return existing }

        // Transfers have no book column: their ledger is the source account's
        // (or the destination's if the source was deleted).
        let account = transfer.source
        let bookID = account?.bookID ?? transfer.destination?.bookID
        let base = baseAmount ?? transfer.fee
        let row = TransactionModel(
            note: "",
            category: feeCategory(in: context, bookID: bookID),
            account: account,
            baseAmount: base,
            income: false,
            amount: transfer.fee,
            date: transfer.date,
            transferFeeOf: transfer.id,
            bookID: bookID
        )
        context.insert(row)
        return row
    }

    /// Removes the fee row(s) belonging to `transfer`.
    static func deleteFeeRows(for transfer: TransferModel, in context: ModelContext) {
        for row in feeRows(in: context) where row.transferFeeOf == transfer.id {
            context.delete(row)
        }
    }

    /// The expense row is the truth for a fee; `TransferModel.fee` is only
    /// there to display it and seed a missing row. Zeroing it when the user
    /// deletes the row is what stops `migrate` from re-creating a charge the
    /// user deliberately removed on the next launch.
    static func detachFeeRow(_ row: TransactionModel, in context: ModelContext) {
        guard let transferID = row.transferFeeOf else { return }
        let descriptor = FetchDescriptor<TransferModel>(
            predicate: #Predicate { $0.id == transferID })
        for transfer in (try? context.fetch(descriptor)) ?? [] {
            transfer.fee = 0
        }
    }

    /// Finds (or creates) the "Transfer Fee" expense category, so the row shows
    /// up in the category breakdown instead of as an uncategorised expense.
    static func feeCategory(in context: ModelContext, bookID: UUID? = BookModel.defaultID) -> CategoryModel? {
        let name = String.appLocalized(categoryNameKey)
        let descriptor = FetchDescriptor<CategoryModel>(
            predicate: #Predicate { $0.income == false })
        let allExpenses = (try? context.fetch(descriptor)) ?? []
        // Never borrow a category from another book: the fee row inherits the
        // transfer's ledger, so its category must be in the same one.
        let expense = allExpenses.filter {
            BookScope.matches($0.bookID, selected: bookID ?? BookModel.defaultID)
        }

        // Match on the name in the current language *or* on the icon/colour we
        // create it with: switching the app language must not leave a second
        // "Transfer Fee" category behind.
        if let existing = expense.first(where: { $0.name == name })
            ?? expense.first(where: { $0.wrappedEmoji == "🧾" && $0.colour.uppercased() == "#8E8E93" }) {
            return existing
        }

        let category = CategoryModel(
            name: name,
            emoji: "🧾",
            colour: "#8E8E93",
            income: false,
            order: (expense.map(\.order).max() ?? 0) + 1,
            bookID: bookID
        )
        context.insert(category)
        return category
    }
}
