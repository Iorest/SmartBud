//
//  BatchEdit.swift
//  smartbud
//
//  Eligibility and result accounting for multi-select bill editing. The
//  fields that decide whether a row may be changed are copied into a value
//  type, so the rules stay Foundation-only and can be tested without
//  SwiftData. A row whose identity belongs to another record (refund, claim
//  repayment, write-off, installment plan, real balance adjustment) is never
//  touched by a batch operation: editing it in isolation would desynchronise
//  the pair and change money the user did not ask to change.
//

import Foundation

enum BatchEditField: String, Sendable, CaseIterable {
    case category, book, note, date, account, labels, reimbursable, excludeFromTotals
}

/// Why one row was not changed. `messageKey` groups the precise codes into the
/// few messages the UI shows, so a failure is always attributable without
/// adding a translation for every internal distinction.
enum BatchEditRejection: String, Sendable, Equatable {
    case linkedRefund
    case linkedClaim
    case settledClaim
    case linkedBadDebt
    case planGenerated
    case balanceAdjustment
    case currencyMismatch
    case invalidValue

    var messageKey: String {
        switch self {
        case .linkedRefund, .linkedClaim, .settledClaim, .linkedBadDebt:
            return "Linked records cannot be batch edited"
        case .planGenerated:
            return "Plan-generated rows cannot be batch edited"
        case .balanceAdjustment:
            return "Balance adjustments cannot be batch edited"
        case .currencyMismatch:
            return "Account currency differs; edit the amount instead"
        case .invalidValue:
            return "Invalid value"
        }
    }
}

/// Identity snapshot of one selectable row. Built from a `TransactionModel`
/// by the view model; never persisted.
struct BatchEditRow: Equatable, Sendable {
    let id: UUID
    let isRefund: Bool
    let isReimbursementIncome: Bool
    /// A claim that already has repayments or a write-off. Clearing its flag
    /// would orphan those rows.
    let isSettledClaim: Bool
    let isBadDebt: Bool
    let isPlanGenerated: Bool
    /// A genuine balance correction (has a reason), as opposed to an ordinary
    /// row the user excluded from totals via batch edit (no reason).
    let isBalanceAdjustment: Bool
    let hasAdjustmentReason: Bool

    init(id: UUID,
         isRefund: Bool = false,
         isReimbursementIncome: Bool = false,
         isSettledClaim: Bool = false,
         isBadDebt: Bool = false,
         isPlanGenerated: Bool = false,
         isBalanceAdjustment: Bool = false,
         hasAdjustmentReason: Bool = false) {
        self.id = id
        self.isRefund = isRefund
        self.isReimbursementIncome = isReimbursementIncome
        self.isSettledClaim = isSettledClaim
        self.isBadDebt = isBadDebt
        self.isPlanGenerated = isPlanGenerated
        self.isBalanceAdjustment = isBalanceAdjustment
        self.hasAdjustmentReason = hasAdjustmentReason
    }
}

struct BatchEditFailure: Equatable, Sendable {
    let id: UUID
    let reason: BatchEditRejection
}

struct BatchEditOutcome: Equatable, Sendable {
    let applied: Int
    let rejections: [BatchEditFailure]

    var skipped: Int { rejections.count }

    /// Sorted and deduplicated so the result alert is deterministic.
    var messageKeys: [String] {
        Array(Set(rejections.map(\.reason.messageKey))).sorted()
    }
}

/// Thrown by a view-model mutation that cannot safely apply a field to a row.
/// The policy maps it back to a user-visible reason instead of a generic throw.
struct BatchEditError: Error, Sendable {
    let rejection: BatchEditRejection

    init(_ rejection: BatchEditRejection) { self.rejection = rejection }
}

enum BatchEditPolicy {
    static func rejection(for row: BatchEditRow, field: BatchEditField) -> BatchEditRejection? {
        if row.isRefund { return .linkedRefund }
        if row.isReimbursementIncome { return .linkedClaim }
        if row.isSettledClaim { return .settledClaim }
        if row.isBadDebt { return .linkedBadDebt }
        if row.isPlanGenerated { return .planGenerated }
        if row.isBalanceAdjustment || row.hasAdjustmentReason { return .balanceAdjustment }
        return nil
    }

    /// A category carries its own book id. Keeping a category from the old
    /// book would make the moved row show a category that does not exist in
    /// the target book's statistics. Legacy rows have no book id and stay.
    static func keepsCategory(categoryBookID: UUID?, movingTo bookID: UUID) -> Bool {
        guard let categoryBookID else { return true }
        return categoryBookID == bookID
    }

    /// Applies `mutate` row by row: a rejected or throwing row is skipped and
    /// reported, never rolling back the rows that already succeeded.
    static func apply(_ rows: [BatchEditRow], field: BatchEditField,
                      mutate: (BatchEditRow) throws -> Void) -> BatchEditOutcome {
        var applied = 0
        var rejections: [BatchEditFailure] = []
        for row in rows {
            if let reason = rejection(for: row, field: field) {
                rejections.append(BatchEditFailure(id: row.id, reason: reason))
                continue
            }
            do {
                try mutate(row)
                applied += 1
            } catch let error as BatchEditError {
                rejections.append(BatchEditFailure(id: row.id, reason: error.rejection))
            } catch {
                rejections.append(BatchEditFailure(id: row.id, reason: .invalidValue))
            }
        }
        return BatchEditOutcome(applied: applied, rejections: rejections)
    }
}
