//
//  InstallmentLedger.swift
//  smartbud
//
//  Materialises the bills of an installment plan. A principal row raises the
//  linked account balance towards zero — the only "used limit" model this app
//  has — and a fee row is an ordinary expense. Both are stamped with the plan
//  id, period and kind so a plan edit can never duplicate a booked bill.
//
//  Rows are created only for executed periods. `AccountBalance` deliberately
//  counts future-dated rows, so pre-generating principal rows would restore
//  the card's credit before the money was actually paid.
//

import Foundation
import SwiftData

@MainActor
enum InstallmentLedger {

    struct SyncResult {
        var created = 0
        var kept = 0
        var removed = 0
    }

    /// Generated rows for one plan. `#Predicate` cannot compare an optional
    /// UUID reliably in the app's SwiftData build, so the rows are filtered in
    /// memory after a cheap `!= nil` predicate, as the other ledgers do.
    static func rows(for plan: InstallmentPlanModel, in context: ModelContext) -> [TransactionModel] {
        let descriptor = FetchDescriptor<TransactionModel>(
            predicate: #Predicate { $0.installmentOf != nil })
        return (try? context.fetch(descriptor))?
            .filter { $0.installmentOf == plan.id } ?? []
    }

    /// Bring a plan's generated rows in line with its current terms.
    ///
    /// Booked periods (`index <= executedPeriods`) are immutable: editing an
    /// amount or a date after the fact must not rewrite a bill the user has
    /// already recorded. Future periods have no rows until they are booked,
    /// so editing the plan simply changes the shape of the next bill.
    /// Calling this twice never creates a second row for the same period.
    @discardableResult
    static func sync(_ plan: InstallmentPlanModel, in context: ModelContext) -> SyncResult {
        let schedule = InstallmentPolicy.schedule(principal: plan.principal, fee: plan.fee,
                                                  periods: plan.periods, firstDate: plan.firstDate)
        guard !schedule.isEmpty else { return SyncResult() }

        let existing = rows(for: plan, in: context)
        var keys = Set(existing.map { "\($0.installmentPeriod)-\($0.installmentKind)" })
        var result = SyncResult()
        let booked = min(max(plan.executedPeriods, 0), plan.periods)

        for period in schedule where period.index <= booked {
            for kind in [1, 2] {
                let key = "\(period.index)-\(kind)"
                if keys.contains(key) {
                    result.kept += 1
                    continue
                }
                context.insert(makeRow(period: period, kind: kind, plan: plan))
                keys.insert(key)
                result.created += 1
            }
        }
        // A shorter term or a rewound counter must not leave stale rows behind.
        for row in existing where row.installmentPeriod > booked {
            context.delete(row)
            result.removed += 1
        }
        return result
    }

    /// Book the next period: advance the counter and create its two rows.
    /// Returns nil when every period is already booked.
    @discardableResult
    static func bookNext(_ plan: InstallmentPlanModel, in context: ModelContext) -> SyncResult? {
        guard plan.executedPeriods < plan.periods else { return nil }
        plan.executedPeriods += 1
        return sync(plan, in: context)
    }

    /// Remove every generated row when the plan itself is deleted.
    static func prepareForDeletion(_ plan: InstallmentPlanModel, in context: ModelContext) {
        for row in rows(for: plan, in: context) { context.delete(row) }
    }

    /// Credit restored on the linked account, capped at the plan principal.
    static func restoredPrincipal(_ plan: InstallmentPlanModel) -> Double {
        InstallmentPolicy.restoredLimit(principal: plan.principal,
                                        periods: plan.periods,
                                        executed: plan.executedPeriods)
    }

    private static func makeRow(period: InstallmentPolicy.Period, kind: Int,
                                plan: InstallmentPlanModel) -> TransactionModel {
        let isPrincipal = kind == 2
        let amount = isPrincipal ? period.principal : period.fee
        let row = TransactionModel(
            note: isPrincipal
                ? "分期本金 \(period.index)/\(plan.periods)"
                : "分期手续费 \(period.index)/\(plan.periods)",
            category: isPrincipal ? nil : plan.category,
            account: plan.account,
            baseAmount: amount,
            income: isPrincipal,
            amount: amount,
            date: period.date,
            installmentOf: plan.id,
            installmentPeriod: period.index,
            installmentKind: kind
        )
        row.bookID = plan.bookID
        return row
    }
}
