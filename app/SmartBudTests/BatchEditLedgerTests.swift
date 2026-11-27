//
//  BatchEditLedgerTests.swift
//  SmartBudTests
//
//  Differential checks against the ledger links: a multi-select edit may
//  touch ordinary rows, but must leave the other side of a refund, a claim
//  repayment or a write-off exactly as it was.
//

import Foundation
import SwiftData
import Testing

@MainActor
@Suite("Batch edit keeps ledger links")
struct BatchEditLedgerTests {
    private let container: ModelContainer
    private var context: ModelContext { container.mainContext }

    init() throws {
        container = try ModelContainer(
            for: Schema([
                TransactionModel.self,
                CategoryModel.self,
                AccountModel.self,
                TransferModel.self,
                CurrencyRate.self,
                BudgetModel.self,
                MainBudgetModel.self,
                TemplateTransactionModel.self
            ]),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    private func row(note: String, amount: Double = 20) -> TransactionModel {
        let account = AccountModel(name: "Cash", currencyCode: "USD", openingBalance: 0)
        let category = CategoryModel(name: "Food")
        context.insert(account)
        context.insert(category)
        let txn = TransactionModel(note: note, category: category, account: account,
                                   baseAmount: amount, income: false,
                                   amount: amount, date: Date(timeIntervalSince1970: 1_700_000_000))
        context.insert(txn)
        return txn
    }

    /// Mirrors the view-model's identity snapshot. A test target does not see
    /// the app target's extension initialiser, so build it from the real row
    /// fields here instead.
    private func snapshot(_ txn: TransactionModel) -> BatchEditRow {
        BatchEditRow(
            id: txn.id,
            isRefund: txn.isRefund,
            isReimbursementIncome: txn.isReimbursementIncome,
            isSettledClaim: txn.reimbursable
                && (txn.reimbursedAmount > 0 || txn.reimbursedAt != nil
                    || txn.badDebtAt != nil),
            isBadDebt: txn.badDebtOf != nil,
            isPlanGenerated: txn.installmentOf != nil,
            hasAdjustmentReason: txn.adjustmentReason != nil
        )
    }

    @Test("A refund and a repayment row are recognised as linked from their real fields")
    func linkedRowsAreClassified() {
        let original = row(note: "Purchase")
        let refund = row(note: "Refund")
        refund.refundOf = original.id
        let claim = row(note: "Claim")
        claim.reimbursable = true
        claim.reimbursedAmount = 10
        let repayment = row(note: "Repayment")
        repayment.income = true
        repayment.reimbursementOf = claim.id

        #expect(BatchEditPolicy.rejection(for: snapshot(refund), field: .note) == .linkedRefund)
        #expect(BatchEditPolicy.rejection(for: snapshot(claim), field: .note) == .settledClaim)
        #expect(BatchEditPolicy.rejection(for: snapshot(repayment), field: .note) == .linkedClaim)
        #expect(BatchEditPolicy.rejection(for: snapshot(original), field: .note) == nil)
    }

    @Test("A batch edits ordinary rows and leaves refund and claim links untouched")
    func partialBatchPreservesLinks() {
        let purchase = row(note: "Purchase")
        let refund = row(note: "Refund")
        refund.refundOf = purchase.id
        let claim = row(note: "Claim")
        claim.reimbursable = true
        let repayment = row(note: "Repayment")
        repayment.income = true
        repayment.reimbursementOf = claim.id
        // Pending claim: a claim with repayments would be intentionally skipped.

        let selected = [purchase, refund, claim, repayment]
        let outcome = BatchEditPolicy.apply(selected.map(snapshot), field: .note) { item in
            // The view-model closure edits by id; mirror that here so the
            // assertion covers the same routing a real batch action uses.
            guard let txn = selected.first(where: { $0.id == item.id }) else { return }
            txn.note = "Batch note"
        }

        #expect(outcome.applied == 2)
        #expect(outcome.skipped == 2)
        #expect(purchase.note == "Batch note")
        #expect(claim.note == "Batch note")
        #expect(refund.note == "Refund")
        #expect(repayment.note == "Repayment")
        #expect(refund.refundOf == purchase.id)
        #expect(repayment.reimbursementOf == claim.id)
        #expect(claim.reimbursable == true)
    }

    @Test("A write-off pair cannot be split by a batch note edit")
    func writeOffPairIsProtected() {
        let claim = row(note: "Claim")
        claim.reimbursable = true
        let loss = row(note: "Loss")
        loss.badDebtOf = claim.id
        claim.badDebtAt = Date(timeIntervalSince1970: 1_700_010_000)

        let outcome = BatchEditPolicy.apply([claim, loss].map(snapshot), field: .note) { item in
            Issue.record("No row in this pair may be edited, got \(item.id)")
        }
        #expect(outcome.applied == 0)
        #expect(outcome.skipped == 2)
        #expect(loss.badDebtOf == claim.id)
        #expect(claim.badDebtAt != nil)
    }
}
