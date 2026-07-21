import SwiftUI
import SwiftData
import Observation

struct SummaryData: Equatable {
    let spent: Double
    let income: Double
    let net: Double
    let positive: Bool
    let average: Double
}

@MainActor
@Observable
final class InsightsViewModel{
    static let shared = InsightsViewModel()
    private let repo = DataRepository.shared

    var selectedPeriod: Int = 2
    var summary: SummaryData = SummaryData(spent: 0, income: 0, net: 0, positive: true, average: 0)
    var lineGraphData: [LineGraphDataPoint] = []

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
            start = cal.date(byAdding: .day, value: -7, to: now)!
            avgDivisor = 7
        case 3:
            start = cal.date(byAdding: .year, value: -1, to: now)!
            avgDivisor = 12
        default:
            start = cal.date(byAdding: .month, value: -1, to: now)!
            avgDivisor = Double(cal.range(of: .day, in: .month, for: now)?.count ?? 30)
        }
        let filtered = all.filter { ($0.date ?? .distantPast) >= start }
        let spent = filtered.filter { !$0.income }.reduce(0) { $0 + $1.amount }
        let income = filtered.filter(\.income).reduce(0) { $0 + $1.amount }
        let net = income - spent
        summary = SummaryData(spent: spent, income: income, net: abs(net), positive: net >= 0, average: abs(net) / avgDivisor)
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
        case 1: start = cal.date(byAdding: .day, value: -7, to: today)!; step = .day; periods = 7
        case 3: start = cal.date(byAdding: .month, value: -12, to: today)!; step = .month; periods = 12
        default: start = cal.date(byAdding: .month, value: -1, to: today)!; step = .day; periods = cal.range(of: .day, in: .month, for: start)?.count ?? 30
        }
        var result = [LineGraphDataPoint]()
        var cursor = start
        for _ in 0..<periods {
            let next = cal.date(byAdding: step, value: 1, to: cursor)!
            let sum = all.filter { ($0.date ?? .distantPast) >= cursor && ($0.date ?? .distantPast) < next }.reduce(0) { $0 + ($1.income ? $1.amount : -$1.amount) }
            result.append(LineGraphDataPoint(date: cursor, amount: sum))
            cursor = next
        }
        lineGraphData = result
    }

    // Analytics wrappers

    func getTotalSpent(type: Int) -> Double {
        let all = repo.fetch(TransactionModel.self)
        return all.filter { periodMatch($0, type: type) && !$0.income }.reduce(0) { $0 + $1.amount }
    }

    func getTotalIncome(type: Int) -> Double {
        let all = repo.fetch(TransactionModel.self)
        return all.filter { periodMatch($0, type: type) && $0.income }.reduce(0) { $0 + $1.amount }
    }

    func getTotalNet(type: Int) -> (value: Double, positive: Bool) {
        let all = repo.fetch(TransactionModel.self)
        let filtered = all.filter { periodMatch($0, type: type) }
        var net = 0.0
        for t in filtered { net += t.income ? t.amount : -t.amount }
        return (abs(net), net >= 0)
    }

    func getLineGraphDataNet(type: Int) -> [LineGraphDataPoint] {
        let all = repo.fetch(TransactionModel.self, sort: [SortDescriptor(\.date, order: .forward)])
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date.now)
        let start: Date; let step: Calendar.Component; let count: Int
        switch type {
        case 1, 2: start = cal.date(byAdding: .day, value: -7, to: today)!; step = .day; count = 7
        case 3: start = cal.date(byAdding: .day, value: -30, to: today)!; step = .day; count = 30
        default: start = cal.date(byAdding: .month, value: -12, to: today)!; step = .month; count = 12
        }
        var result = [LineGraphDataPoint]()
        var cursor = start
        for _ in 0..<count {
            let next = cal.date(byAdding: step, value: 1, to: cursor)!
            let sum = all.filter { ($0.date ?? .distantPast) >= cursor && ($0.date ?? .distantPast) < next }.reduce(0) { $0 + ($1.income ? $1.amount : -$1.amount) }
            result.append(LineGraphDataPoint(date: cursor, amount: sum))
            cursor = next
        }
        return result
    }

    func getInsights(type: Int, date: Date, income: Bool) -> (amount: Double, maximum: Double, average: Double, numberOfDays: Int, dates: [Date], dateDictionary: [Date: Double]) {
        let all = repo.fetch(TransactionModel.self).filter { ($0.date ?? .distantPast) >= date && $0.income == income }
        var iter = date; let cal = Calendar.current
        let count: Int
        switch type { case 1: count = 7; case 2: count = cal.range(of: .day, in: .month, for: date)?.count ?? 30; default: count = 12 }
        var dates = [Date](); var dict = [Date: Double](); var total = 0.0;     var maxAmount = 0.0; var days = 0
        let step: Calendar.Component = type == 3 ? .month : .day
        for _ in 0..<count {
            let next = cal.date(byAdding: step, value: 1, to: iter)!
            let sum = all.filter { ($0.date ?? .distantPast) >= iter && ($0.date ?? .distantPast) < next }.reduce(0) { $0 + $1.amount }
            total += sum; dict[iter] = sum
            if sum > maxAmount { maxAmount = sum }; if sum != 0 { days += 1 }
            dates.append(iter); iter = next
        }
        return (total, maxAmount, total / Double(max(count, 1)), days, dates, dict)
    }

    func getInsightsSummary(type: Int, date: Date) -> (spent: Double, income: Double, net: Double, positive: Bool, average: Double) {
        let all = repo.fetch(TransactionModel.self).filter { ($0.date ?? .distantPast) >= date }
        let spent = all.filter { !$0.income }.reduce(0) { $0 + $1.amount }
        let inc = all.filter(\.income).reduce(0) { $0 + $1.amount }
        let net = inc - spent
        let count = max(1, type == 1 ? 7 : (type == 2 ? 30 : 12))
        return (spent, inc, abs(net), net >= 0, abs(net) / Double(count))
    }

    private func periodMatch(_ txn: TransactionModel, type: Int) -> Bool {
        let d = txn.date ?? .distantPast
        let cal = Calendar.current
        let now = Date.now
        switch type {
        case 1: return d >= cal.startOfDay(for: now)
        case 2: return d >= cal.date(byAdding: .day, value: -7, to: now)!
        case 3: return d >= cal.date(byAdding: .month, value: -1, to: now)!
        default: return d >= cal.date(byAdding: .year, value: -1, to: now)!
        }
    }

    // MARK: - Log View (LogView filter periods: 1=today, 2=week, 3=month, 4=year, 5=all time)

    /// Start of the period for LogView's timeframe control, respecting the user's
    /// configured first-weekday/first-day-of-month. `nil` means "all time" (no lower bound).
    private func logViewPeriodStart(type: Int) -> Date? {
        var calendar = Calendar(identifier: .gregorian)
        let defaults = UserDefaults.appGroup
        calendar.firstWeekday = defaults.integer(forKey: "firstWeekday")
        calendar.minimumDaysInFirstWeek = 4
        switch type {
        case 1:
            return calendar.startOfDay(for: .now)
        case 2:
            let comps = calendar.dateComponents([.weekOfYear, .yearForWeekOfYear], from: .now)
            return calendar.date(from: comps)
        case 3:
            let startDay = defaults.integer(forKey: "firstDayOfMonth")
            return getStartOfMonth(startDay: startDay)
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
        if let income {
            all = all.filter { $0.income == income }
        }
        return all
    }

    func getLogViewTotalSpent(type: Int) -> Double {
        logViewTransactions(type: type, income: false).reduce(0) { $0 + $1.amount }
    }

    func getLogViewTotalIncome(type: Int) -> Double {
        logViewTransactions(type: type, income: true).reduce(0) { $0 + $1.amount }
    }

    func getLogViewTotalNet(type: Int) -> (value: Double, positive: Bool) {
        var net = 0.0
        for t in logViewTransactions(type: type, income: nil) { net += t.income ? t.amount : -t.amount }
        return (abs(net), net >= 0)
    }

    /// A trailing window of buckets ending today, matching the legacy LogView graph:
    /// timeframe 1/2 -> last 7 days, 3 -> last 30 days, 4 -> last 12 months, 5 (all time) -> none.
    private func logLineGraphBuckets(type: Int) -> (dates: [Date], step: Calendar.Component)? {
        guard type != 5 else { return nil }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let step: Calendar.Component = type == 4 ? .month : .day
        let periods = type == 4 ? 12 : (type == 3 ? 30 : 7)
        guard let start = calendar.date(byAdding: step, value: -periods, to: today) else { return nil }
        var dates = [Date]()
        var cursor = start
        while cursor <= today {
            dates.append(cursor)
            cursor = calendar.date(byAdding: step, value: 1, to: cursor)!
        }
        return (dates, step)
    }

    /// Cumulative running net balance (income - spent, over all-time history) sampled at each bucket.
    func getLogLineGraphDataNet(type: Int) -> [LineGraphDataPoint] {
        guard let (dates, step) = logLineGraphBuckets(type: type), let start = dates.first else { return [] }
        let calendar = Calendar.current
        let all = repo.fetch(TransactionModel.self)
        var runningTotal = all.filter { ($0.date ?? .distantPast) < start }
            .reduce(0.0) { $0 + ($1.income ? $1.amount : -$1.amount) }
        return dates.map { bucketStart in
            let bucketEnd = calendar.date(byAdding: step, value: 1, to: bucketStart)!
            runningTotal += all.filter { let d = $0.date ?? .distantPast; return d >= bucketStart && d < bucketEnd }
                .reduce(0.0) { $0 + ($1.income ? $1.amount : -$1.amount) }
            return LineGraphDataPoint(date: bucketStart, amount: runningTotal)
        }
    }

    /// Per-bucket total (not cumulative) of either income-only or spend-only transactions.
    func getLogLineGraphData(income: Bool, type: Int) -> [LineGraphDataPoint] {
        guard let (dates, step) = logLineGraphBuckets(type: type) else { return [] }
        let calendar = Calendar.current
        let all = repo.fetch(TransactionModel.self).filter { $0.income == income }
        return dates.map { bucketStart in
            let bucketEnd = calendar.date(byAdding: step, value: 1, to: bucketStart)!
            let total = all.filter { let d = $0.date ?? .distantPast; return d >= bucketStart && d < bucketEnd }
                .reduce(0.0) { $0 + $1.amount }
            return LineGraphDataPoint(date: bucketStart, amount: total)
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

        let graphData: [LineGraphDataPoint]
        switch insightsType {
        case 2: graphData = getLogLineGraphData(income: true, type: timeframe)
        case 3: graphData = getLogLineGraphData(income: false, type: timeframe)
        default: graphData = getLogLineGraphDataNet(type: timeframe)
        }
        let green: Bool
        switch insightsType {
        case 1: green = (graphData.first?.amount ?? 0) < (graphData.last?.amount ?? 0)
        case 2: green = true
        default: green = false
        }

        let defaults = UserDefaults.appGroup
        let showCents = defaults.bool(forKey: "showCents")

        let amount: Double
        let headingKey: String.LocalizationValue
        switch insightsType {
        case 2:
            amount = totalIncome
            headingKey = "Earned"
        case 3:
            amount = totalSpent
            headingKey = "Spent"
        default:
            amount = netValue
            headingKey = "Net total"
        }

        let rangeLabelKey: String.LocalizationValue
        switch timeframe {
        case 1: rangeLabelKey = "today"
        case 3: rangeLabelKey = "this month"
        case 4: rangeLabelKey = "this year"
        case 5: rangeLabelKey = "all time"
        default: rangeLabelKey = "this week"
        }

        return LogInsightsData(
            totalSpent: totalSpent,
            totalIncome: totalIncome,
            netValue: netValue,
            netPositive: netPositive,
            lineGraphData: graphData,
            lineGraphGreen: green,
            range: logViewRangeCount(timeframe: timeframe),
            rangeLabel: String.appLocalized(rangeLabelKey),
            headingText: String.appLocalized(headingKey),
            amount: amount,
            formattedIncome: "+\(formatNumber(showCents: showCents, number: totalIncome))",
            formattedSpent: "-\(formatNumber(showCents: showCents, number: totalSpent))"
        )
    }

    /// Day/month count from the start of the current period to today, used by
    /// `LineGraph` for its x-axis labels. Mirrors the legacy view's `range` Int.
    private func logViewRangeCount(timeframe: Int) -> Int {
        var calendar = Calendar(identifier: .gregorian)
        let defaults = UserDefaults.appGroup
        calendar.firstWeekday = defaults.integer(forKey: "firstWeekday")
        calendar.minimumDaysInFirstWeek = 4
        switch timeframe {
        case 3:
            let comps = calendar.dateComponents([.month, .year], from: .now)
            let monthStart = calendar.date(from: comps) ?? .now
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

    private func formatNumber(showCents: Bool, number: Double) -> String {
        if showCents {
            return String(format: "%.2f", number)
        } else {
            return String(format: "%d", Int(floor(number)))
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
            return txns.reduce(0.0) { $0 + ($1.income ? $1.amount : -$1.amount) }
        } else {
            return txns.reduce(0.0) { $0 + $1.amount }
        }
    }

    // MARK: - Redesign (SwiftData / "Insights" screen)

    /// One bar on `BarGraph`. `label` is rendered under the bar (M/T/W/T/F/S/S for week, day number for month, "Jan"/"Apr"/… for year).
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
    var periodDateRangeText: String = ""
    var periodTotalNet: Double = 0
    var periodNetPositive: Bool = true
    var periodTotalIncome: Double = 0
    var periodTotalSpent: Double = 0
    var periodAverage: Double = 0
    var periodDateRangeIncomeText: String = ""
    var periodAverageIncome: Double = 0
    var barChartData: [BarChartPoint] = []
    var categoryBreakdown: [PowerCategory] = []
    var todayTotal: Double = 0
    var todayCount: Int = 0
    var todayTransactions: [TransactionModel] = []
    var yesterdayTotal: Double = 0
    var yesterdayTransactions: [TransactionModel] = []
    var currency: String = Locale.current.currency?.identifier ?? "USD"
    var showCents: Bool = true
    var currencySymbol: String = Locale.appLocale.currencySymbol ?? "$"

    /// Gregorian calendar with the user's first-weekday preference applied.
    private var configuredCalendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        let defaults = UserDefaults.appGroup
        cal.firstWeekday = defaults.integer(forKey: "firstWeekday")
        cal.minimumDaysInFirstWeek = 4
        return cal
    }

    /// Returns (start, end-exclusive) for the given period. For week this is the user's
    /// first-weekday to the following 6th day. For month, the 1st of the month to the 1st
    /// of next month. For year, Jan 1 to Jan 1 of next year.
    func getPeriodDateRange(for period: Int) -> (start: Date, end: Date) {
        let cal = configuredCalendar
        let now = Date.now
        switch period {
        case 1:
            let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
            let start = cal.date(from: comps) ?? cal.startOfDay(for: now)
            let end = cal.date(byAdding: .day, value: 7, to: start) ?? start
            return (start, end)
        case 3:
            let comps = cal.dateComponents([.year], from: now)
            let start = cal.date(from: comps) ?? cal.startOfDay(for: now)
            let end = cal.date(byAdding: .year, value: 1, to: start) ?? start
            return (start, end)
        default:
            let comps = cal.dateComponents([.year, .month], from: now)
            let start = cal.date(from: comps) ?? cal.startOfDay(for: now)
            let end = cal.date(byAdding: .month, value: 1, to: start) ?? start
            return (start, end)
        }
    }

    /// Recomputes every new `@Published` property above for the current `selectedPeriod`.
    /// Also refreshes today / yesterday transaction lists.
    func refreshAll() {
        let defaults = UserDefaults.appGroup
        showCents = defaults.bool(forKey: "showCents")
        currency = defaults.string(forKey: "currency") ?? Locale.current.currency?.identifier ?? "USD"
        currencySymbol = currencySymbolFor(code: currency)

        let (periodStart, periodEnd) = getPeriodDateRange(for: selectedPeriod)
        let all = repo.fetch(TransactionModel.self)
        let inPeriod = all.filter { t in
            guard let d = t.date else { return false }
            return d >= periodStart && d < periodEnd
        }
        let spent = inPeriod.filter { !$0.income }.reduce(0.0) { $0 + $1.amount }
        let inc = inPeriod.filter(\.income).reduce(0.0) { $0 + $1.amount }
        let net = inc - spent
        periodTotalSpent = spent
        periodTotalIncome = inc
        periodTotalNet = abs(net)
        periodNetPositive = net >= 0

        let divisor: Double
        switch selectedPeriod {
        case 1: divisor = 7
        case 3: divisor = 12
        default:
            divisor = Double(configuredCalendar.range(of: .day, in: .month, for: periodStart)?.count ?? 30)
        }
        periodAverage = abs(net) / max(1, divisor)
        periodAverageIncome = inc / max(1, divisor)

        periodDateRangeText = getDateRangeText(for: selectedPeriod)
        periodDateRangeIncomeText = selectedPeriod == 3 ? String.appLocalized("AVG/MONTH", comment: "Insights avg per month") : String.appLocalized("AVG/DAY", comment: "Insights avg per day")

        barChartData = getBarChartData(for: selectedPeriod)
        categoryBreakdown = getCategoryBreakdown(for: selectedPeriod)

        let cal = configuredCalendar
        let today = cal.startOfDay(for: .now)
        let tomorrow = cal.date(byAdding: .day, value: 1, to: today) ?? today
        let yesterday = cal.date(byAdding: .day, value: -1, to: today) ?? today

        let todayTxns = inPeriod
            .filter { ($0.date ?? .distantPast) >= today && ($0.date ?? .distantPast) < tomorrow }
            .sorted { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
        todayTransactions = todayTxns
        todayCount = todayTxns.count
        todayTotal = todayTxns.reduce(0.0) { $0 + ($1.income ? $1.amount : -$1.amount) }

        let yesterdayTxns = inPeriod
            .filter { ($0.date ?? .distantPast) >= yesterday && ($0.date ?? .distantPast) < today }
            .sorted { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
        yesterdayTransactions = yesterdayTxns
        yesterdayTotal = yesterdayTxns.reduce(0.0) { $0 + ($1.income ? $1.amount : -$1.amount) }
    }

    /// Bar-chart buckets for the period. Week: 7 daily buckets, single-letter M T W T F S S labels.
    /// Month: `count` daily buckets matching the actual days in the period (28/29/30/31),
    /// every 7th day labelled (1, 8, 15, 22, 29). Year: 12 monthly buckets.
    func getBarChartData(for period: Int) -> [BarChartPoint] {
        let cal = configuredCalendar
        let (start, _) = getPeriodDateRange(for: period)
        let all = repo.fetch(TransactionModel.self)

        let count: Int
        let step: Calendar.Component
        let weekdayLetters = cal.veryShortWeekdaySymbols   // ["S","M","T","W","T","F","S"]
        switch period {
        case 1: count = 7; step = .day
        case 3: count = 12; step = .month
        default:
            // Match the period's actual day count (28/29/30/31), not a hardcoded 30.
            count = cal.range(of: .day, in: .month, for: start)?.count ?? 30
            step = .day
        }

        var result = [BarChartPoint]()
        var cursor = start
        let monthLetters = cal.veryShortMonthSymbols      // ["J","F","M",...]
        for index in 0..<count {
            let next = cal.date(byAdding: step, value: 1, to: cursor) ?? cursor
            let sum = all
                .filter { !$0.income }
                .filter { if let d = $0.date { return d >= cursor && d < next } else { return false } }
                .reduce(0.0) { $0 + $1.amount }

            let label: String
            switch period {
            case 1:
                let weekday = cal.component(.weekday, from: cursor)
                label = weekdayLetters[(weekday - 1 + weekdayLetters.count) % weekdayLetters.count]
            case 3:
                let month = cal.component(.month, from: cursor)
                label = monthLetters[max(0, min(month - 1, monthLetters.count - 1))]
            default:
                if index % 7 == 0 {
                    let day = cal.component(.day, from: cursor)
                    label = "\(day)"
                } else {
                    label = ""
                }
            }
            result.append(BarChartPoint(date: cursor, amount: sum, label: label))
            cursor = next
        }
        return result
    }

    /// For each expense category, total amount in the period. Sorted by percent desc.
    /// Percent is share of total spend (capped at 1.0).
    func getCategoryBreakdown(for period: Int) -> [PowerCategory] {
        let (periodStart, periodEnd) = getPeriodDateRange(for: period)
        let txns = repo.fetch(TransactionModel.self).filter { t in
            guard let d = t.date, !t.income, let cat = t.category else { return false }
            return d >= periodStart && d < periodEnd && !cat.income
        }
        var amounts = [UUID: Double]()
        var categories = [UUID: CategoryModel]()
        for t in txns {
            guard let cat = t.category else { continue }
            amounts[cat.id, default: 0] += t.amount
            categories[cat.id] = cat
        }
        let total = amounts.values.reduce(0, +)
        guard total > 0 else { return [] }
        let entries: [PowerCategory] = amounts.compactMap { (id, amount) in
            guard let cat = categories[id] else { return nil }
            return PowerCategory(id: id, category: cat, percent: min(1, amount / total), amount: amount)
        }
        return entries.sorted { $0.percent > $1.percent }
    }

    func getTodayTransactions() -> [TransactionModel] {
        let cal = configuredCalendar
        let today = cal.startOfDay(for: .now)
        let tomorrow = cal.date(byAdding: .day, value: 1, to: today) ?? today
        return repo.fetch(TransactionModel.self)
            .filter { if let d = $0.date { return d >= today && d < tomorrow } else { return false } }
            .sorted { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
    }

    func getYesterdayTransactions() -> [TransactionModel] {
        let cal = configuredCalendar
        let today = cal.startOfDay(for: .now)
        let yesterday = cal.date(byAdding: .day, value: -1, to: today) ?? today
        return repo.fetch(TransactionModel.self)
            .filter { if let d = $0.date { return d >= yesterday && d < today } else { return false } }
            .sorted { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
    }

    func getPeriodAverage(for period: Int) -> Double {
        let (start, end) = getPeriodDateRange(for: period)
        let all = repo.fetch(TransactionModel.self).filter { if let d = $0.date { return d >= start && d < end } else { return false } }
        let net = all.reduce(0.0) { $0 + ($1.income ? $1.amount : -$1.amount) }
        let divisor: Double
        switch period {
        case 1: divisor = 7
        case 3: divisor = 12
        default:
            let cal = configuredCalendar
            divisor = Double(cal.range(of: .day, in: .month, for: start)?.count ?? 30)
        }
        return abs(net) / max(1, divisor)
    }

    func getPeriodTotalIncome(for period: Int) -> Double {
        let (start, end) = getPeriodDateRange(for: period)
        return repo.fetch(TransactionModel.self)
            .filter { if let d = $0.date { return d >= start && d < end && $0.income } else { return false } }
            .reduce(0.0) { $0 + $1.amount }
    }

    func getPeriodTotalSpent(for period: Int) -> Double {
        let (start, end) = getPeriodDateRange(for: period)
        return repo.fetch(TransactionModel.self)
            .filter { if let d = $0.date { return d >= start && d < end && !$0.income } else { return false } }
            .reduce(0.0) { $0 + $1.amount }
    }

    func getPeriodTotalNet(for period: Int) -> (value: Double, positive: Bool) {
        let (start, end) = getPeriodDateRange(for: period)
        let all = repo.fetch(TransactionModel.self).filter { if let d = $0.date { return d >= start && d < end } else { return false } }
        let net = all.reduce(0.0) { $0 + ($1.income ? $1.amount : -$1.amount) }
        return (abs(net), net >= 0)
    }

    /// Formats `amount` using the current `currency` and `showCents` settings. Pass `sign` to force
    /// a leading "+" / "-" (e.g. for net totals).
    func formattedCurrency(_ amount: Double, withCents: Bool? = nil, sign: Bool = false) -> String {
        let cents = withCents ?? showCents
        let formatter = NumberFormatter()
        formatter.locale = Locale.appLocale
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        formatter.maximumFractionDigits = cents ? 2 : 0
        let str = formatter.string(from: NSNumber(value: abs(amount))) ?? "0"
        if !sign { return str }
        return amount >= 0 ? "+\(str)" : "-\(str)"
    }

    /// Period text shown above the totals: "5 FEB - 11 FEB" / "1 - 30 APR" / "2024".
    /// Matches the GitHub reference design which renders the month abbreviation uppercase.
    func getDateRangeText(for period: Int) -> String {
        let cal = configuredCalendar
        let (start, end) = getPeriodDateRange(for: period)
        let dayMonth = DateFormatter()
        dayMonth.locale = Locale.appLocale
        dayMonth.dateFormat = "d MMM"
        dayMonth.calendar = cal
        let yearOnly = DateFormatter()
        yearOnly.locale = Locale.appLocale
        yearOnly.dateFormat = "yyyy"
        yearOnly.calendar = cal
        switch period {
        case 1:
            let endInclusive = cal.date(byAdding: .day, value: -1, to: end) ?? end
            return "\(dayMonth.string(from: start).uppercased()) - \(dayMonth.string(from: endInclusive).uppercased())"
        case 3:
            return yearOnly.string(from: start)
        default:
            let endInclusive = cal.date(byAdding: .day, value: -1, to: end) ?? end
            return "\(dayMonth.string(from: start).uppercased()) - \(dayMonth.string(from: endInclusive).uppercased())"
        }
    }

    private func currencySymbolFor(code: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = code
        formatter.locale = Locale.appLocale
        return formatter.currencySymbol ?? code
    }
}
