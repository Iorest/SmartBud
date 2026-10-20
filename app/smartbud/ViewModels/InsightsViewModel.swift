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
final class InsightsViewModel {
    static let shared = InsightsViewModel()
    private let repo = DataRepository.shared

    var selectedPeriod: Int = 2
    var summary: SummaryData = SummaryData(spent: 0, income: 0, net: 0, positive: true, average: 0)
    var lineGraphData: [LineGraphDataPoint] = []

    var periodDateRangeText: String = ""
    var periodTotalNet: Double = 0
    var periodNetPositive: Bool = true
    var periodTotalIncome: Double = 0
    var periodTotalSpent: Double = 0
    var periodAverage: Double = 0
    var barChartData: [BarChartPoint] = []
    var categoryBreakdown: [PowerCategory] = []
    var todayTotal: Double = 0
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
        let inPeriod = all.filter { txn in
            guard let date = txn.date else { return false }
            return date >= periodStart && date < periodEnd
        }
        let spent = Money.sum(inPeriod.filter { !$0.income }.map(\.amount))
        let inc = Money.sum(inPeriod.filter(\.income).map(\.amount))
        let net = inc - spent
        periodTotalSpent = Money.double(spent)
        periodTotalIncome = Money.double(inc)
        periodTotalNet = Money.double(abs(net))
        periodNetPositive = net >= 0

        let divisor: Int
        switch selectedPeriod {
        case 1: divisor = 7
        case 3: divisor = 12
        default:
            divisor = configuredCalendar.range(of: .day, in: .month, for: periodStart)?.count ?? 30
        }
        periodAverage = Money.double(abs(net) / Decimal(max(1, divisor)))

        periodDateRangeText = getDateRangeText(for: selectedPeriod)

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
        todayTotal = Money.double(Money.sum(todayTxns.map { $0.income ? $0.amount : -$0.amount }))

        let yesterdayTxns = inPeriod
            .filter { ($0.date ?? .distantPast) >= yesterday && ($0.date ?? .distantPast) < today }
            .sorted { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
        yesterdayTransactions = yesterdayTxns
        yesterdayTotal = Money.double(Money.sum(yesterdayTxns.map { $0.income ? $0.amount : -$0.amount }))
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
            let sum = Money.sum(all
                .filter { !$0.income }
                .filter {
                    if let date = $0.date { return date >= cursor && date < next }
                    return false
                }
                .map(\.amount))

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
            result.append(BarChartPoint(date: cursor, amount: Money.double(sum), label: label))
            cursor = next
        }
        return result
    }

    /// For each expense category, total amount in the period. Sorted by percent desc.
    /// Percent is share of total spend (capped at 1.0).
    func getCategoryBreakdown(for period: Int) -> [PowerCategory] {
        let (periodStart, periodEnd) = getPeriodDateRange(for: period)
        let txns = repo.fetch(TransactionModel.self).filter { txn in
            guard let date = txn.date, !txn.income, let category = txn.category else { return false }
            return date >= periodStart && date < periodEnd && !category.income
        }
        var amounts = [UUID: Decimal]()
        var categories = [UUID: CategoryModel]()
        for txn in txns {
            guard let category = txn.category else { continue }
            amounts[category.id, default: 0] += Money.cents(txn.amount)
            categories[category.id] = category
        }
        let total = amounts.values.reduce(Decimal.zero, +)
        guard total > 0 else { return [] }
        let entries: [PowerCategory] = amounts.compactMap { (id, amount) in
            guard let cat = categories[id] else { return nil }
            return PowerCategory(id: id, category: cat,
                                 percent: min(1, Money.double(amount / total)),
                                 amount: Money.double(amount))
        }
        return entries.sorted { $0.percent > $1.percent }
    }

    /// Formats `amount` using the current `currency` and `showCents` settings. Pass `sign` to force
    /// a leading "+" / "-" (e.g. for net totals).
    func formattedCurrency(_ amount: Double, withCents: Bool? = nil, sign: Bool = false) -> String {
        Money.format(amount, currencyCode: currency,
                     showsCents: withCents ?? showCents,
                     plus: sign ? amount >= 0 : nil)
    }

    /// Period text shown above the totals: "5 FEB - 11 FEB" / "1 - 30 APR" / "2024".
    /// Matches the GitHub reference design which renders the month abbreviation uppercase.
    ///
    /// The `"d MMM"` template only reads correctly in Latin-script locales where
    /// `MMM` is a 3-letter month abbreviation ("FEB", "JUL"). In `zh-Hans` /
    /// `zh-Hant` the same template renders "17 7月" — `MMM` becomes the full
    /// month-with-suffix form, and the unspaced layout collapses to "17月" in
    /// the small header. Branch the template per locale so CJK users see the
    /// natural "M月d日 - M月d日" order instead.
    func getDateRangeText(for period: Int) -> String {
        let cal = configuredCalendar
        let (start, end) = getPeriodDateRange(for: period)
        let isCJK = Locale.appLocale.identifier.hasPrefix("zh")
        let dayMonth = DateFormatter()
        dayMonth.locale = Locale.appLocale
        dayMonth.dateFormat = isCJK ? "M月d日" : "d MMM"
        dayMonth.calendar = cal
        let yearOnly = DateFormatter()
        yearOnly.locale = Locale.appLocale
        yearOnly.dateFormat = "yyyy"
        yearOnly.calendar = cal
        let formatRange: (Date) -> String = { date in
            let label = dayMonth.string(from: date)
            return isCJK ? label : label.uppercased()
        }
        switch period {
        case 1:
            let endInclusive = cal.date(byAdding: .day, value: -1, to: end) ?? end
            return "\(formatRange(start)) - \(formatRange(endInclusive))"
        case 3:
            return yearOnly.string(from: start)
        default:
            let endInclusive = cal.date(byAdding: .day, value: -1, to: end) ?? end
            return "\(formatRange(start)) - \(formatRange(endInclusive))"
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
        let spent = Money.sum(filtered.filter { !$0.income }.map(\.amount))
        let income = Money.sum(filtered.filter(\.income).map(\.amount))
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
        default: start = cal.date(byAdding: .month, value: -1, to: today) ?? today; step = .day; periods = cal.range(of: .day, in: .month, for: start)?.count ?? 30
        }
        var result = [LineGraphDataPoint]()
        var cursor = start
        for _ in 0..<periods {
            let next = cal.date(byAdding: step, value: 1, to: cursor) ?? cursor
            let sum = Money.sum(all.filter { ($0.date ?? .distantPast) >= cursor && ($0.date ?? .distantPast) < next }
                .map { $0.income ? $0.amount : -$0.amount })
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
        Money.double(Money.sum(logViewTransactions(type: type, income: false).map(\.amount)))
    }

    func getLogViewTotalIncome(type: Int) -> Double {
        Money.double(Money.sum(logViewTransactions(type: type, income: true).map(\.amount)))
    }

    func getLogViewTotalNet(type: Int) -> (value: Double, positive: Bool) {
        let net = Money.sum(logViewTransactions(type: type, income: nil)
            .map { $0.income ? $0.amount : -$0.amount })
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
            .map { $0.income ? $0.amount : -$0.amount })
        return dates.map { bucketStart in
            let bucketEnd = calendar.date(byAdding: step, value: 1, to: bucketStart) ?? bucketStart
            runningTotal += Money.sum(all.filter {
                let date = $0.date ?? .distantPast
                return date >= bucketStart && date < bucketEnd
            }
                .map { $0.income ? $0.amount : -$0.amount })
            return LineGraphDataPoint(date: bucketStart, amount: Money.double(runningTotal))
        }
    }

    /// Per-bucket total (not cumulative) of either income-only or spend-only transactions.
    func getLogLineGraphData(income: Bool, type: Int) -> [LineGraphDataPoint] {
        guard let (dates, step) = logLineGraphBuckets(type: type) else { return [] }
        let calendar = Calendar.current
        let all = repo.fetch(TransactionModel.self).filter { $0.income == income }
        return dates.map { bucketStart in
            let bucketEnd = calendar.date(byAdding: step, value: 1, to: bucketStart) ?? bucketStart
            let total = Money.sum(all.filter {
                let date = $0.date ?? .distantPast
                return date >= bucketStart && date < bucketEnd
            }
                .map(\.amount))
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
        let headingKey: String
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

        let rangeLabelKey: String
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
            return number.formatted(.number.precision(.fractionLength(2)))
        } else {
            return Int(floor(number)).formatted(.number)
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
            return Money.double(Money.sum(txns.map { $0.income ? $0.amount : -$0.amount }))
        } else {
            return Money.double(Money.sum(txns.map(\.amount)))
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
}
