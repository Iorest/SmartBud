//
//  InsightsViewModel+Log.swift
//  smartbud
//
import SwiftUI
import SwiftData
import Observation

extension InsightsViewModel {

    func setPeriod(_ type: Int) { selectedPeriod = type; refresh() }
    func refresh() { refreshSummary(); refreshLineGraph() }

    // MARK: Summary

    func refreshSummary() {
        let all = repo.fetch(TransactionModel.self)
        let cal = Calendar.current
        let now = Date.now
        let start: Date
        let avgDivisor: Double
        switch selectedPeriod {
        case 1:
            start = cal.date(byAdding: .day, value: -7, to: now) ?? now
            avgDivisor = 7
        case 3:
            start = cal.date(byAdding: .year, value: -1, to: now) ?? now
            avgDivisor = 12
        default:
            start = cal.date(byAdding: .month, value: -1, to: now) ?? now
            avgDivisor = Double(cal.range(of: .day, in: .month, for: now)?.count ?? 30)
        }
        let filtered = all.filter { ($0.date ?? .distantPast) >= start }
        // Refunds reduce spend where the money arrived (they are not income).
        let spent = Money.sum(filtered.map(\.spendBaseAmount))
        let income = Money.sum(filtered.filter(\.countsAsIncome).map(\.wrappedBaseAmount))
        let net = income - spent
        summary = SummaryData(spent: Money.double(spent), income: Money.double(income),
                              net: Money.double(abs(net)), positive: net >= 0,
                              average: Money.double(abs(net) / Decimal(avgDivisor)))
    }

    // MARK: Line Graph

    func refreshLineGraph() {
        let all = repo.fetch(TransactionModel.self, sort: [SortDescriptor(\.date, order: .forward)])
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date.now)
        let start: Date
        let step: Calendar.Component
        let periods: Int
        switch selectedPeriod {
        case 1: start = cal.date(byAdding: .day, value: -7, to: today) ?? today; step = .day; periods = 7
        case 3: start = cal.date(byAdding: .month, value: -12, to: today) ?? today; step = .month; periods = 12
        default:
            start = cal.date(byAdding: .month, value: -1, to: today) ?? today
            step = .day
            periods = cal.range(of: .day, in: .month, for: start)?.count ?? 30
        }
        var result = [LineGraphDataPoint]()
        var cursor = start
        for _ in 0..<periods {
            let next = cal.date(byAdding: step, value: 1, to: cursor) ?? cursor
            let sum = Money.sum(all.filter {
                let date = $0.date ?? .distantPast
                return date >= cursor && date < next && date <= .now
            }.map(\.signedBaseAmount))
            result.append(LineGraphDataPoint(date: cursor, amount: Money.double(sum)))
            cursor = next
        }
        lineGraphData = result
    }

    // Analytics wrappers

    // MARK: - Log View (LogView filter periods: 1=today, 2=week, 3=month, 4=year, 5=all time)

    /// Start of the period for LogView's timeframe control, respecting the user's
    /// configured first-weekday/first-day-of-month. `nil` means "all time" (no lower bound).
    private func logViewPeriodStart(type: Int) -> Date? {
        let defaults = UserDefaults.appGroup
        // A missing key used to leave `firstWeekday` at 0, which is not a valid
        // weekday; the shared helper clamps it and applies the app language.
        let calendar = AppPeriod.configuredCalendar(
            firstWeekday: defaults.integer(forKey: "firstWeekday"))
        switch type {
        case 1:
            return calendar.startOfDay(for: .now)
        case 2:
            let comps = calendar.dateComponents([.weekOfYear, .yearForWeekOfYear], from: .now)
            return calendar.date(from: comps)
        case 3:
            let startDay = defaults.integer(forKey: "firstDayOfMonth")
            return AppPeriod.monthStart(containing: .now, startDay: startDay, calendar: calendar)
        case 4:
            let comps = calendar.dateComponents([.year], from: .now)
            return calendar.date(from: comps)
        default:
            return nil
        }
    }

    private func logViewTransactions(type: Int, income: Bool?) -> [TransactionModel] {
        var all = repo.fetch(TransactionModel.self).filter { ($0.date ?? .distantPast) <= .now }
        if let start = logViewPeriodStart(type: type) {
            all = all.filter { ($0.date ?? .distantPast) >= start }
        }
        switch income {
        case .some(false): all = all.filter { $0.countsAsSpend || $0.isRefund }
        case .some(true): all = all.filter(\.countsAsIncome)
        case .none: all = all.filter(\.countsInTotals)
        }
        return all
    }

    func getLogViewTotalSpent(type: Int) -> Double {
        Money.double(Money.sum(logViewTransactions(type: type, income: false).map(\.spendBaseAmount)))
    }

    func getLogViewTotalIncome(type: Int) -> Double {
        Money.double(Money.sum(logViewTransactions(type: type, income: true).map(\.wrappedBaseAmount)))
    }

    func getLogViewTotalNet(type: Int) -> (value: Double, positive: Bool) {
        let net = Money.sum(logViewTransactions(type: type, income: nil)
            .map(\.signedBaseAmount))
        return (Money.double(abs(net)), net >= 0)
    }

    /// A trailing window of exactly `periods` buckets ending today:
    /// timeframe 1/2 -> last 7 days, 3 -> last 30 days, 4 -> last 12 months,
    /// 5 (all time) -> none. The old loop produced one extra bucket (8/31/13).
    private func logLineGraphBuckets(type: Int) -> (dates: [Date], step: Calendar.Component)? {
        guard type != 5 else { return nil }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let step: Calendar.Component = type == 4 ? .month : .day
        let periods = type == 4 ? 12 : (type == 3 ? 30 : 7)
        guard let start = calendar.date(byAdding: step, value: -(periods - 1), to: today) else { return nil }
        var dates = [Date]()
        var cursor = start
        for _ in 0..<periods {
            dates.append(cursor)
            cursor = calendar.date(byAdding: step, value: 1, to: cursor) ?? today
        }
        return (dates, step)
    }

    /// Cumulative running net balance (income - spent, over all-time history) sampled at each bucket.
    func getLogLineGraphDataNet(type: Int) -> [LineGraphDataPoint] {
        guard let (dates, step) = logLineGraphBuckets(type: type), let start = dates.first else { return [] }
        let calendar = Calendar.current
        let all = repo.fetch(TransactionModel.self)
        var runningTotal = Money.sum(all.filter { ($0.date ?? .distantPast) < start }
            .map(\.signedBaseAmount))
        return dates.map { bucketStart in
            let bucketEnd = calendar.date(byAdding: step, value: 1, to: bucketStart) ?? bucketStart
            runningTotal += Money.sum(all.filter {
                let date = $0.date ?? .distantPast
                return date >= bucketStart && date < bucketEnd
            }
                .map(\.signedBaseAmount))
            return LineGraphDataPoint(date: bucketStart, amount: Money.double(runningTotal))
        }
    }

    /// Per-bucket total (not cumulative) of either income-only or spend-only transactions.
    func getLogLineGraphData(income: Bool, type: Int) -> [LineGraphDataPoint] {
        guard let (dates, step) = logLineGraphBuckets(type: type) else { return [] }
        let calendar = Calendar.current
        let all = repo.fetch(TransactionModel.self).filter {
            income ? $0.countsAsIncome : ($0.countsAsSpend || $0.isRefund)
        }
        return dates.map { bucketStart in
            let bucketEnd = calendar.date(byAdding: step, value: 1, to: bucketStart) ?? bucketStart
            // A refund subtracts from its bucket; clamped at zero because the
            // line graph has no negative region.
            let total = Money.sum(all.filter {
                let date = $0.date ?? .distantPast
                return date >= bucketStart && date < bucketEnd
            }
                .map { income ? $0.wrappedBaseAmount : max(0, $0.spendBaseAmount) })
            return LineGraphDataPoint(date: bucketStart, amount: Money.double(total))
        }
    }

    // MARK: - LogInsightsView (LogView card)

    /// Pre-computed snapshot used by `LogInsightsView`. Refresh whenever
    /// `timeframe` or `insightsType` change. The view consumes this struct
    /// instead of running aggregation/formatting logic in its body.
    struct LogInsightsData: Equatable {
        let totalSpent: Double
        let totalIncome: Double
        let netValue: Double        // abs(net)
        let netPositive: Bool
        let lineGraphData: [LineGraphDataPoint]
        let lineGraphGreen: Bool
        let range: Int              // day/month count for the line graph
        let rangeLabel: String      // localized "Today" / "This Week" / ...
        let headingText: String     // localized "Net total" / "Earned" / "Spent"
        let amount: Double          // raw value displayed by NumberView
        let formattedIncome: String // "+123.45" / "+123"
        let formattedSpent: String  // "-123.45" / "-123"
    }

    /// Pre-computes all data needed to render the `LogInsightsView` card.
    /// - Parameter timeframe: 1=today, 2=week, 3=month, 4=year, 5=all time
    /// - Parameter insightsType: 1=net, 2=income, 3=spent
    @MainActor
    func logInsightsData(timeframe: Int, insightsType: Int) -> LogInsightsData {
        let totalSpent = getLogViewTotalSpent(type: timeframe)
        let totalIncome = getLogViewTotalIncome(type: timeframe)
        let (netValue, netPositive) = getLogViewTotalNet(type: timeframe)
        let graphData = lineGraphData(for: insightsType, timeframe: timeframe)
        let (amount, headingKey) = amountAndHeading(for: insightsType,
                                                    spent: totalSpent,
                                                    income: totalIncome,
                                                    net: netValue)
        let showCents = UserDefaults.appGroup.bool(forKey: "showCents")

        return LogInsightsData(
            totalSpent: totalSpent,
            totalIncome: totalIncome,
            netValue: netValue,
            netPositive: netPositive,
            lineGraphData: graphData,
            lineGraphGreen: lineIsGreen(graphData, insightsType: insightsType),
            range: logViewRangeCount(timeframe: timeframe),
            rangeLabel: String.appLocalized(rangeLabelKey(for: timeframe)),
            headingText: String.appLocalized(headingKey),
            amount: amount,
            formattedIncome: Money.format(totalIncome, currencyCode: currency,
                                          showsCents: showCents, plus: true, locale: .appLocale),
            formattedSpent: Money.format(totalSpent, currencyCode: currency,
                                         showsCents: showCents, plus: false, locale: .appLocale)
        )
    }

    private func lineGraphData(for insightsType: Int, timeframe: Int) -> [LineGraphDataPoint] {
        switch insightsType {
        case 2: return getLogLineGraphData(income: true, type: timeframe)
        case 3: return getLogLineGraphData(income: false, type: timeframe)
        default: return getLogLineGraphDataNet(type: timeframe)
        }
    }

    /// The line is green when the net trend is rising (income and spend cards
    /// use their own fixed colours).
    private func lineIsGreen(_ data: [LineGraphDataPoint], insightsType: Int) -> Bool {
        switch insightsType {
        case 1: return (data.first?.amount ?? 0) < (data.last?.amount ?? 0)
        case 2: return true
        default: return false
        }
    }

    private func amountAndHeading(for insightsType: Int, spent: Double,
                                  income: Double, net: Double) -> (Double, String) {
        switch insightsType {
        case 2: return (income, "Earned")
        case 3: return (spent, "Spent")
        default: return (net, "Net total")
        }
    }

    private func rangeLabelKey(for timeframe: Int) -> String {
        switch timeframe {
        case 1: return "today"
        case 3: return "this month"
        case 4: return "this year"
        case 5: return "all time"
        default: return "this week"
        }
    }

    /// Day/month count from the start of the current period to today, used by
    /// `LineGraph` for its x-axis labels. Mirrors the legacy view's `range` Int.
    private func logViewRangeCount(timeframe: Int) -> Int {
        let defaults = UserDefaults.appGroup
        // A missing key used to leave `firstWeekday` at 0, which is not a valid
        // weekday; the shared helper clamps it and applies the app language.
        let calendar = AppPeriod.configuredCalendar(
            firstWeekday: defaults.integer(forKey: "firstWeekday"))
        switch timeframe {
        case 3:
            let startDay = defaults.integer(forKey: "firstDayOfMonth")
            let monthStart = AppPeriod.monthStart(containing: .now, startDay: startDay,
                                                  calendar: calendar)
            return (calendar.dateComponents([.day], from: monthStart, to: .now).day ?? 0) + 1
        case 4:
            let comps = calendar.dateComponents([.year], from: .now)
            let yearStart = calendar.date(from: comps) ?? .now
            return (calendar.dateComponents([.month], from: yearStart, to: .now).month ?? 0) + 1
        default:
            let comps = calendar.dateComponents([.weekOfYear, .yearForWeekOfYear], from: .now)
            let weekStart = calendar.date(from: comps) ?? .now
            return (calendar.dateComponents([.day], from: weekStart, to: .now).day ?? 0) + 1
        }
    }

    // MARK: - Shortcuts / App Intents

    /// Used by the "Get Insights" Shortcut.
    /// - Parameters:
    ///   - type: 1 = net total, 2 = income total, 3 = spent total
    ///   - timeframe: 1=today, 2=week, 3=month, 4=year, 5=all time (LogView period scheme)
    ///   - optionalIncome: nil for net; true for income-only; false for spent-only
    ///   - categories: optional category filter (empty means no filter)
    func getShortcutInsights(type: Int, timeframe: Int, optionalIncome: Bool?, categories: [CategoryModel]) -> Double {
        var txns = logViewTransactions(type: timeframe, income: optionalIncome)
        if !categories.isEmpty {
            let ids = Set(categories.map(\.id))
            txns = txns.filter { $0.category.map { ids.contains($0.id) } ?? false }
        }
        if type == 1 {
            return Money.double(Money.sum(txns.map(\.signedBaseAmount)))
        }
        let spentType = optionalIncome == false
        return Money.double(Money.sum(txns.map { spentType ? $0.spendBaseAmount : $0.wrappedBaseAmount }))
    }

    // MARK: - Redesign (SwiftData / "Insights" screen)

    /// One bar on `BarGraph`. `label` is rendered under the bar
    /// (M/T/W/T/F/S/S for week, day number for month, "Jan"/"Apr"/… for year).
    struct BarChartPoint: Identifiable, Equatable {
        let id: UUID
        let date: Date
        let amount: Double
        let label: String

        init(id: UUID = UUID(), date: Date, amount: Double, label: String) {
            self.id = id
            self.date = date
            self.amount = amount
            self.label = label
        }
    }

    // Period state (1=week, 2=month, 3=year).
}
