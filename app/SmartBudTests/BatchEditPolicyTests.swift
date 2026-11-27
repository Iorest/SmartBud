//
//  BatchEditPolicyTests.swift
//  SmartBudTests
//
//  The rules that keep a multi-select edit from rewriting a row whose
//  identity belongs to another record. Foundation-only so they run in the
//  Linux harness too.
//

import Foundation
import Testing

@Suite("Batch edit policy")
struct BatchEditPolicyTests {

    private func row(
        _ id: Int,
        refund: Bool = false,
        repayment: Bool = false,
        settledClaim: Bool = false,
        badDebt: Bool = false,
        plan: Bool = false,
        adjustmentReason: Bool = false
    ) -> BatchEditRow {
        BatchEditRow(
            id: UUID(uuidString: "00000000-0000-0000-0000-00000000000\(id)")!,
            isRefund: refund,
            isReimbursementIncome: repayment,
            isSettledClaim: settledClaim,
            isBadDebt: badDebt,
            isPlanGenerated: plan,
            hasAdjustmentReason: adjustmentReason
        )
    }

    @Test("Linked rows are rejected for every field, ordinary rows are not")
    func linkedRowsAreIneligible() {
        let linked: [BatchEditRow] = [
            row(1, refund: true),
            row(2, repayment: true),
            row(3, settledClaim: true),
            row(4, badDebt: true),
            row(5, plan: true),
            row(6, adjustmentReason: true)
        ]
        for field in BatchEditField.allCases {
            for item in linked {
                #expect(BatchEditPolicy.rejection(for: item, field: field) != nil,
                        "\(field) must not edit linked row \(item.id)")
            }
            #expect(BatchEditPolicy.rejection(for: row(0), field: field) == nil)
        }
    }

    @Test("A rejected row does not stop the rest; each failure keeps its id and reason")
    func partialFailure() {
        let rows = [row(1), row(2, refund: true), row(3), row(4, settledClaim: true)]
        var edited: [UUID] = []
        let outcome = BatchEditPolicy.apply(rows, field: .note) { item in
            edited.append(item.id)
        }
        #expect(outcome.applied == 2)
        #expect(outcome.skipped == 2)
        #expect(edited == [rows[0].id, rows[2].id])
        #expect(outcome.rejections.map(\.reason) == [.linkedRefund, .settledClaim])
        #expect(outcome.rejections.map(\.id) == [rows[1].id, rows[3].id])
    }

    @Test("A throwing row is skipped and reported as an invalid value")
    func invalidValueIsolation() {
        struct BadValue: Error {}
        let rows = [row(1), row(2), row(3)]
        let outcome = BatchEditPolicy.apply(rows, field: .account) { item in
            if item.id == rows[1].id { throw BadValue() }
        }
        #expect(outcome.applied == 2)
        #expect(outcome.rejections.count == 1)
        #expect(outcome.rejections[0].reason == .invalidValue)
        #expect(outcome.rejections[0].id == rows[1].id)
    }

    @Test("An ordinary row excluded from totals can be included again")
    func exclusionRoundTrip() {
        let excluded = row(1) // excluded rows carry no adjustment reason
        #expect(BatchEditPolicy.rejection(for: excluded, field: .excludeFromTotals) == nil)
        #expect(BatchEditPolicy.rejection(for: row(2, adjustmentReason: true),
                                          field: .excludeFromTotals) == .balanceAdjustment)
    }

    @Test("Moving books drops a category owned by the old book")
    func categoryScopeOnBookMove() {
        let target = UUID()
        #expect(BatchEditPolicy.keepsCategory(categoryBookID: nil, movingTo: target))
        #expect(BatchEditPolicy.keepsCategory(categoryBookID: target, movingTo: target))
        #expect(!BatchEditPolicy.keepsCategory(categoryBookID: UUID(), movingTo: target))
    }

    @Test("Failure groups are stable and deduplicated for the result alert")
    func failureMessages() {
        let rows = [row(1, refund: true), row(2, repayment: true), row(3, badDebt: true)]
        let outcome = BatchEditPolicy.apply(rows, field: .book) { _ in }
        #expect(outcome.messageKeys == ["Linked records cannot be batch edited"])
    }

    @Test("A book move refuses rows whose account lives in another ledger")
    func crossBookAccountIsRejected() {
        let target = UUID()
        let foreign = BatchEditRow(id: UUID(), accountBookID: UUID())
        let matching = BatchEditRow(id: UUID(), accountBookID: target)
        #expect(BatchEditPolicy.rejection(for: foreign, field: .book,
                                          targetBookID: target) == .accountBookMismatch)
        #expect(BatchEditPolicy.rejection(for: matching, field: .book,
                                          targetBookID: target) == nil)
        #expect(BatchEditPolicy.rejection(for: foreign, field: .note) == nil)
    }

    @Test("A book move refuses rows that other rows point at, or that are transfer fees")
    func bookMoveKeepsLinkedRowsTogether() {
        let target = UUID()
        let refunded = BatchEditRow(id: UUID(), isReferencedByOtherRows: true)
        let fee = BatchEditRow(id: UUID(), isTransferFee: true)
        #expect(BatchEditPolicy.rejection(for: refunded, field: .book,
                                          targetBookID: target) == .linkedRefund)
        #expect(BatchEditPolicy.rejection(for: fee, field: .book,
                                          targetBookID: target) == .linkedRefund)
        #expect(BatchEditPolicy.rejection(for: BatchEditRow(id: UUID()), field: .book,
                                          targetBookID: target) == nil)
    }
}
