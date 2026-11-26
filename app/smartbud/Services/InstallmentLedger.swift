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
    /// amount, a date or even the term must never rewrite or delete a bill the
    /// user has already recorded. Only missing non-zero rows are created.
    /// `sync` never deletes a row — `prepareForDeletion` is the only path that
    /// removes generated bills, and it runs when the plan itself is deleted.
    /// Calling this twice never creates a second row for the same period.
    @discardableResult
    static func sync(_ plan: inout InstallmentPlanModel, in context: ModelContext) -> SyncResult {
        // A plan cannot have fewer periods than it has already booked. An
        // imported or hand-edited value otherwise leaves an out-of-range
        // counter that changes on the next export/import round trip.
        if plan.periods < plan.executedPeriods {
            plan.periods = plan.executedPeriods
        }
        InstallmentPlanStore.upsert(plan, in: context)
        let schedule = InstallmentPolicy.schedule(principal: plan.principal, fee: plan.fee,
                                                  periods: plan.periods, firstDate: plan.firstDate)
        guard !schedule.isEmpty else { return SyncResult() }

        let existing = rows(for: plan, in: context)
        var keys = Set(existing.map { "\($0.installmentPeriod)-\($0.installmentKind)" })
        var result = SyncResult()
        let booked = min(max(plan.executedPeriods, 0), plan.periods)

        for period in schedule where period.index <= booked {
            for kind in [1, 2] {
                let amount = kind == 2 ? period.principal : period.fee
                // A zero-amount bill is not a transaction: the app rejects
                // ¥0 rows on entry, and interest-free plans have no fee row.
                guard Money.cents(amount) > 0 else { continue }
                let key = "\(period.index)-\(kind)"
                if keys.contains(key) {
                    result.kept += 1
                    continue
                }
                context.insert(makeRow(period: period, kind: kind, plan: plan, in: context))
                keys.insert(key)
                result.created += 1
            }
        }
        return result
    }

    /// Book the next period: advance the counter and create its two rows.
    /// Returns nil when every period is already booked.
    @discardableResult
    static func bookNext(_ plan: inout InstallmentPlanModel, in context: ModelContext) -> SyncResult? {
        guard plan.executedPeriods < plan.periods else { return nil }
        plan.executedPeriods += 1
        return sync(&plan, in: context)
    }

    /// Remove every generated row and the plan itself.
    static func prepareForDeletion(_ plan: InstallmentPlanModel, in context: ModelContext) {
        for row in rows(for: plan, in: context) { context.delete(row) }
        InstallmentPlanStore.remove(id: plan.id, in: context)
    }

    /// Credit restored on the linked account, capped at the plan principal.
    static func restoredPrincipal(_ plan: InstallmentPlanModel) -> Double {
        InstallmentPolicy.restoredLimit(principal: plan.principal,
                                        periods: plan.periods,
                                        executed: plan.executedPeriods)
    }

    /// Plans are Codable values on the default book, not a SwiftData entity.
    static func plans(in context: ModelContext) -> [InstallmentPlanModel] {
        InstallmentPlanStore.all(in: context)
    }

    private static func makeRow(period: InstallmentPolicy.Period, kind: Int,
                                plan: InstallmentPlanModel,
                                in context: ModelContext) -> TransactionModel {
        let isPrincipal = kind == 2
        let amount = isPrincipal ? period.principal : period.fee
        let accounts = (try? context.fetch(FetchDescriptor<AccountModel>())) ?? []
        let categories = (try? context.fetch(FetchDescriptor<CategoryModel>())) ?? []
        let account = accounts.first { $0.id == plan.accountID }
        let category = categories.first { $0.id == plan.categoryID }
        let row = TransactionModel(
            note: isPrincipal
                ? "分期本金 \(period.index)/\(plan.periods)"
                : "分期手续费 \(period.index)/\(plan.periods)",
            category: isPrincipal ? nil : category,
            account: account,
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
