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

/// Period metadata for the integer `type` stored on both budget models
/// (1=day, 2=week, 3=month, 4=year). The label switch and the end-date switch
/// used to be copy-pasted into the two budget cards, the Shortcuts intent and
/// both models.
enum BudgetPeriod {
    /// Localisation key for the "current period" label on a budget card.
    static func labelKey(for type: Int) -> String {
        switch type {
        case 1: return "today"
        case 2: return "this week"
        case 3: return "this month"
        case 4: return "this year"
        default: return "this week"
        }
    }

    /// End of the period that starts at `startDate`.
    static func endDate(from startDate: Date, type: Int, calendar: Calendar = .current) -> Date {
        switch type {
        case 1: return calendar.date(byAdding: .day, value: 1, to: startDate) ?? startDate
        case 2: return calendar.date(byAdding: .day, value: 7, to: startDate) ?? startDate
        case 3: return calendar.date(byAdding: .month, value: 1, to: startDate) ?? startDate
        case 4: return calendar.date(byAdding: .year, value: 1, to: startDate) ?? startDate
        default: return startDate
        }
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
    /// Upper bound on rows materialised in one catch-up pass. One year of
    /// daily occurrences is already far more than a ledger should backfill.
    static let maxCatchUp = 366

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

// MARK: - Budget forecast

/// One spend contribution inside a budget period. The caller supplies an
/// already-signed, base-currency amount (refunds are negative), so this layer
/// never needs SwiftData or the ledger rules.
struct BudgetForecastEntry {
    let date: Date
    let spend: Double
}

enum BudgetForecast {
    struct Result: Equatable {
        let spent: Double
        let projectedSpend: Double
        let overspend: Double
        let elapsedDays: Int
        let totalDays: Int
        let excludedOutlierCount: Int
    }

    /// A row above `outlierMultiplier × median` is a one-off purchase, not a
    /// spending pace. A median needs at least three rows before it means
    /// anything, so shorter histories are left untouched.
    static let outlierMultiplier = 3.0
    static let minimumEntriesForOutlierCheck = 3

    /// Projects the period's spend from the elapsed fraction. Returns nil when
    /// the feature is off or the budget/period is unusable, so every caller
    /// gets the same "no forecast" answer instead of inventing a fallback.
    static func estimate(
        entries: [BudgetForecastEntry],
        budget: Double,
        periodStart: Date,
        periodEnd: Date,
        enabled: Bool = true,
        excludeOutliers: Bool = true,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> Result? {
        guard enabled, budget.isFinite, budget > 0, periodEnd > periodStart else { return nil }
        let start = calendar.startOfDay(for: periodStart)
        let today = calendar.startOfDay(for: now)
        guard today >= start else { return nil }

        let totalDays = max(1, calendar.dateComponents(
            [.day], from: start, to: calendar.startOfDay(for: periodEnd)).day ?? 0)
        let elapsedDays = min(totalDays, max(1, (calendar.dateComponents(
            [.day], from: start, to: today).day ?? 0) + 1))

        let inPeriod = entries.filter { $0.date >= periodStart && $0.date <= now }
        var included = inPeriod
        var excluded = 0
        if excludeOutliers {
            let positives = inPeriod.map(\.spend).filter { $0.isFinite && $0 > 0 }.sorted()
            if positives.count >= minimumEntriesForOutlierCheck {
                let limit = positives[positives.count / 2] * outlierMultiplier
                included = inPeriod.filter { entry in
                    guard entry.spend > limit else { return true }
                    excluded += 1
                    return false
                }
            }
        }

        let spent = Money.sum(included.map(\.spend))
        let projected = Money.rounded(spent / Decimal(elapsedDays) * Decimal(totalDays))
        return Result(
            spent: Money.double(spent),
            projectedSpend: Money.double(projected),
            overspend: Money.double(max(Decimal.zero, projected - Money.cents(budget))),
            elapsedDays: elapsedDays,
            totalDays: totalDays,
            excludedOutlierCount: excluded
        )
    }
}

// MARK: - Subscription detection

/// A single expense row reduced to the fields the detector needs. `id` is the
/// source row so the UI can turn a suggestion into a real recurring entry.
struct SubscriptionEntry {
    let id: UUID
    let merchantKey: String
    let merchantName: String
    let amount: Double
    let date: Date
    let isRecurring: Bool
}

enum SubscriptionCadence: String {
    case monthly
    case quarterly
    case yearly

    /// Matches `recurringType = 3` (months) on `TransactionModel`.
    var months: Int {
        switch self {
        case .monthly: return 1
        case .quarterly: return 3
        case .yearly: return 12
        }
    }
}

struct SubscriptionSuggestion: Identifiable, Hashable {
    let merchantKey: String
    let merchantName: String
    let amount: Double
    let cadence: SubscriptionCadence
    let lastTransactionID: UUID
    let occurrenceCount: Int

    var id: String { merchantKey }
}

/// Deterministic recurring-payment detection: same merchant key, near-equal
/// amounts and a stable month / quarter / year gap. No model, no network.
enum SubscriptionDetector {
    static let minimumOccurrences = 3
    static let amountTolerance = 0.10
    static let gapTolerance = 0.20
    /// Average days per calendar month; February's 28 and March's 31 both fit.
    private static let daysPerMonth = 30.44

    static func detect(
        _ entries: [SubscriptionEntry],
        now: Date = .now,
        excluding: Set<String> = [],
        calendar: Calendar = .current
    ) -> [SubscriptionSuggestion] {
        let candidates = entries.filter {
            !$0.merchantKey.isEmpty && !$0.isRecurring && !excluding.contains($0.merchantKey)
                && $0.amount.isFinite && $0.amount > 0 && $0.date <= now
        }
        var suggestions = [SubscriptionSuggestion]()

        for (key, group) in Dictionary(grouping: candidates, by: \.merchantKey) {
            let rows = group.sorted { $0.date < $1.date }
            guard rows.count >= minimumOccurrences else { continue }

            var best: [SubscriptionEntry]?
            var run = Array(rows.prefix(1))
            for index in 1..<rows.count {
                let trial = run + [rows[index]]
                if stableCadence(trial, calendar: calendar) != nil {
                    run = trial
                } else {
                    if run.count >= minimumOccurrences, isBetter(run, than: best) { best = run }
                    // The current row can still open the next run together
                    // with its immediate predecessor.
                    run = [rows[index - 1], rows[index]]
                }
            }
            if run.count >= minimumOccurrences, isBetter(run, than: best) { best = run }
            guard let best, let cadence = stableCadence(best, calendar: calendar) else { continue }

            let last = best[best.count - 1]
            suggestions.append(SubscriptionSuggestion(
                merchantKey: key,
                merchantName: last.merchantName,
                amount: median(best.map(\.amount)),
                cadence: cadence,
                lastTransactionID: last.id,
                occurrenceCount: best.count
            ))
        }
        return suggestions.sorted { ($0.amount, $0.merchantKey) > ($1.amount, $1.merchantKey) }
    }

    private static func stableCadence(_ run: [SubscriptionEntry], calendar: Calendar) -> SubscriptionCadence? {
        guard run.count >= minimumOccurrences else { return nil }
        let amounts = run.map(\.amount).sorted()
        let typicalAmount = median(amounts)
        guard typicalAmount > 0,
              amounts.allSatisfy({ abs($0 - typicalAmount) <= typicalAmount * amountTolerance })
        else { return nil }

        var gaps = [Int]()
        for index in 1..<run.count {
            let days = calendar.dateComponents(
                [.day], from: run[index - 1].date, to: run[index].date).day ?? 0
            guard days > 0 else { return nil }
            gaps.append(days)
        }
        let typicalGap = Double(median(gaps))
        var closest: (cadence: SubscriptionCadence, distance: Double)?
        for cadence in [SubscriptionCadence.monthly, .quarterly, .yearly] {
            let expected = daysPerMonth * Double(cadence.months)
            let distance = abs(typicalGap - expected) / expected
            guard distance <= gapTolerance else { continue }
            if closest == nil || distance < closest!.distance { closest = (cadence, distance) }
        }
        guard let closest else { return nil }

        let expected = daysPerMonth * Double(closest.cadence.months)
        guard gaps.allSatisfy({ abs(Double($0) - expected) <= expected * gapTolerance }) else {
            return nil
        }
        return closest.cadence
    }

    private static func isBetter(_ run: [SubscriptionEntry], than best: [SubscriptionEntry]?) -> Bool {
        guard let best else { return true }
        if run.count != best.count { return run.count > best.count }
        let left = median(run.map(\.amount))
        let right = median(best.map(\.amount))
        if left != right { return left > right }
        return run[run.count - 1].date > best[best.count - 1].date
    }

    private static func median(_ values: [Double]) -> Double {
        let sorted = values.sorted()
        return sorted.isEmpty ? 0 : sorted[sorted.count / 2]
    }

    private static func median(_ values: [Int]) -> Int {
        let sorted = values.sorted()
        return sorted.isEmpty ? 0 : sorted[sorted.count / 2]
    }
}

// MARK: - Budget alerts

enum BudgetAlertKind: String {
    case usage80
    case projectedOverspend
}

enum BudgetAlertFrequency: Int {
    case oncePerPeriod = 0
    case daily = 1
}

struct BudgetAlertSnapshot {
    let budgetID: String
    let periodKey: String
    let budget: Double
    let spent: Double
    let forecast: BudgetForecast.Result?
}

struct BudgetAlertRequest: Equatable {
    let kind: BudgetAlertKind
    let budgetID: String
    let dedupeKey: String
}

/// Turns budget numbers into at-most-one notification per kind and budget.
/// The history map is owned by the caller (App Group defaults); keeping the
/// decision pure makes the "do not bombard the user" rule testable.
enum BudgetAlertEvaluator {
    static let usageThreshold = 0.8

    static func periodKey(for start: Date, calendar: Calendar = .current) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: calendar.startOfDay(for: start))
    }

    static func requests(
        for snapshots: [BudgetAlertSnapshot],
        enabled: Bool,
        now: Date = .now,
        frequency: BudgetAlertFrequency,
        history: [String: String],
        calendar: Calendar = .current
    ) -> (requests: [BudgetAlertRequest], history: [String: String]) {
        guard enabled else { return ([], history) }
        var updated = history
        var requests = [BudgetAlertRequest]()

        for snapshot in snapshots where snapshot.budget > 0 {
            let triggered: [(BudgetAlertKind, Bool)] = [
                (.usage80, Money.spendFraction(snapshot.spent, of: snapshot.budget) >= usageThreshold),
                (.projectedOverspend, (snapshot.forecast?.overspend ?? 0) > 0)
            ]
            for (kind, fired) in triggered where fired {
                let key = "\(kind.rawValue)|\(snapshot.budgetID)|\(snapshot.periodKey)"
                let stamp = frequency == .daily
                    ? periodKey(for: now, calendar: calendar)
                    : snapshot.periodKey
                guard updated[key] != stamp else { continue }
                updated[key] = stamp
                requests.append(BudgetAlertRequest(kind: kind,
                                                   budgetID: snapshot.budgetID,
                                                   dedupeKey: key))
            }
        }
        return (requests, updated)
    }
}
