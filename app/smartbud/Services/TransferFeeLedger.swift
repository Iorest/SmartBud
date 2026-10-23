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

        let account = transfer.source
        let base = baseAmount ?? transfer.fee
        let row = TransactionModel(
            note: "",
            category: feeCategory(in: context),
            account: account,
            baseAmount: base,
            income: false,
            amount: transfer.fee,
            date: transfer.date ?? .now,
            transferFeeOf: transfer.id
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

    /// Finds (or creates) the "Transfer Fee" expense category, so the row shows
    /// up in the category breakdown instead of as an uncategorised expense.
    static func feeCategory(in context: ModelContext) -> CategoryModel? {
        let name = String.appLocalized(categoryNameKey)
        let descriptor = FetchDescriptor<CategoryModel>(
            predicate: #Predicate { $0.income == false })
        let expense = (try? context.fetch(descriptor)) ?? []

        if let existing = expense.first(where: { $0.name == name }) { return existing }

        let category = CategoryModel(
            name: name,
            emoji: "🧾",
            colour: "#8E8E93",
            income: false,
            order: (expense.map(\.order).max() ?? 0) + 1
        )
        context.insert(category)
        return category
    }
}
