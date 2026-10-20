//
//  BudgetLogic.swift
//  smartbud
//
//  Pure (SwiftData-free) arithmetic for budget period rollover and recurring
//  transactions, extracted so the advance loops are unit-testable. The
//  previous inline `while endDate <= now` loops hung the main thread forever
//  because the loop condition never became false.
//

import Foundation

/// Advances a budget's `startDate` in whole periods until the period
/// containing `now` is current. Period lengths mirror `BudgetModel.endDate` /
/// `MainBudgetModel.endDate` (1=day, 2=week, 3=month, 4=year).
///
/// Returns `nil` when `type` has no period (`endDate == startDate`), meaning
/// the start date must not move — callers keep the original start date.
enum BudgetRollover {
    static func roll(startDate: Date, type: Int, now: Date = .now,
                     calendar: Calendar = .current) -> Date? {
        let step: Calendar.Component
        let value: Int
        switch type {
        case 1: step = .day; value = 1
        case 2: step = .day; value = 7
        case 3: step = .month; value = 1
        case 4: step = .year; value = 1
        default: return nil
        }
        var start = startDate
        while let end = calendar.date(byAdding: step, value: value, to: start), end <= now {
            start = end
        }
        return start
    }
}

/// Start date for a budget being created or edited. Editing only the amount
/// must keep the existing anchor; a new period type has to be re-anchored
/// from the freshly picked day, otherwise the period would still start on
/// the old type's boundary.
enum BudgetAnchor {
    static func startDate(original: Date?, oldType: Int, newType: Int, computed: Date) -> Date {
        guard let original, oldType == newType else { return computed }
        return original
    }
}

/// Next occurrence of a recurring transaction. Mirrors
/// `TransactionModel.nextTransactionDate` (1=every N days, 2=every N weeks,
/// 3=every N months). Returns `nil` for an unusable recurrence (unknown type
/// or `coefficient <= 0`) so callers stop the loop instead of spinning forever.
enum Recurrence {
    static func nextOccurrence(after day: Date, type: Int, coefficient: Int,
                               calendar: Calendar = .current) -> Date? {
        switch type {
        case 1: return coefficient > 0 ? calendar.date(byAdding: .day, value: coefficient, to: day) : nil
        case 2: return coefficient > 0 ? calendar.date(byAdding: .day, value: coefficient * 7, to: day) : nil
        case 3: return coefficient > 0 ? calendar.date(byAdding: .month, value: coefficient, to: day) : nil
        default: return nil
        }
    }
}
