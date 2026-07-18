import SwiftUI
import SwiftData

struct SummaryData: Equatable {
    let spent: Double
    let income: Double
    let net: Double
    let positive: Bool
    let average: Double
}

@MainActor
final class InsightsViewModel: ObservableObject {
    static let shared = InsightsViewModel()
    private let repo = DataRepository.shared

    @Published var selectedPeriod: Int = 2
    @Published var summary: SummaryData = SummaryData(spent: 0, income: 0, net: 0, positive: true, average: 0)
    @Published var lineGraphData: [LineGraphDataPoint] = []

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
        let defaults = UserDefaults(suiteName: "group.com.rafaelsoh.dime")
        calendar.firstWeekday = defaults?.integer(forKey: "firstWeekday") ?? 0
        calendar.minimumDaysInFirstWeek = 4
        switch type {
        case 1:
            return calendar.startOfDay(for: .now)
        case 2:
            let comps = calendar.dateComponents([.weekOfYear, .yearForWeekOfYear], from: .now)
            return calendar.date(from: comps)
        case 3:
            let startDay = defaults?.integer(forKey: "firstDayOfMonth") ?? 1
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
}
