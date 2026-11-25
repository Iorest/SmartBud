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
    let repo = DataRepository.shared

    var selectedPeriod: Int = 2
    var summary: SummaryData = SummaryData(spent: 0, income: 0, net: 0, positive: true, average: 0)
    var lineGraphData: [LineGraphDataPoint] = []

    var periodDateRangeText: String = ""
    var periodTotalNet: Double = 0
    var periodNetPositive: Bool = true
    var periodTotalIncome: Double = 0
    var periodTotalSpent: Double = 0
    var periodAverage: Double = 0
    /// Spend per day/month for the bar chart's reference line. `periodAverage`
    /// is the *net* average shown next to the net total, which is a different
    /// number as soon as the period has income.
    var periodAverageSpend: Double = 0
    var barChartData: [BarChartPoint] = []
    var categoryBreakdown: [PowerCategory] = []
    /// Spend by merchant, largest first. Grouped on `merchantKey`, so the
    /// three spellings of one shop are one row.
    var merchantBreakdown: [MerchantSlice] = []
    var todayTotal: Double = 0
    var todayTransactions: [TransactionModel] = []
    var yesterdayTotal: Double = 0
    var yesterdayTransactions: [TransactionModel] = []
    /// Expenses waiting to be paid back. Not period-bound: an open claim from
    /// three months ago is still money the user is owed.
    var pendingReimbursements: [TransactionModel] = []
    var pendingReimbursementTotal: Double = 0
    /// Point-in-time totals, not period figures. Card debt is a liability, so
    /// it is excluded from assets and subtracted from net worth.
    var netWorth: Double = 0
    var totalAssets: Double = 0
    var totalDebt: Double = 0
    var currency: String = Locale.current.currency?.identifier ?? "USD"
    var showCents: Bool = true
    var currencySymbol: String = Locale.appLocale.currencySymbol ?? "$"

    /// Gregorian calendar with the user's first-weekday preference applied.
    private var configuredCalendar: Calendar {
        AppPeriod.configuredCalendar(
            firstWeekday: UserDefaults.appGroup.integer(forKey: "firstWeekday"))
    }

    /// Month-start offset from Settings → Time Frames (1…28).
    private var configuredStartDay: Int {
        UserDefaults.appGroup.integer(forKey: "firstDayOfMonth")
    }

    /// Returns (start, end-exclusive) for the given period. Week follows the
    /// user's first weekday, month follows their month-start day, year is the
    /// calendar year. All three come from `AppPeriod` so Log, Insights and the
    /// widgets cannot drift apart.
    func getPeriodDateRange(for period: Int) -> (start: Date, end: Date) {
        let cal = configuredCalendar
        let now = Date.now
        switch period {
        case 1:
            return AppPeriod.weekRange(containing: now, calendar: cal)
        case 3:
            return AppPeriod.yearRange(containing: now, calendar: cal)
        default:
            return AppPeriod.monthRange(containing: now,
                                        startDay: configuredStartDay,
                                        calendar: cal)
        }
    }

    /// Every aggregation starts from the active ledger. A raw fetch would fold
    /// other books' rows into this book's totals, charts and pending claims.
    func bookScopedTransactions() -> [TransactionModel] {
        BookScope.scoped(repo.fetch(TransactionModel.self), \.bookID,
                         selected: BookState.shared.currentID)
    }

    /// Recomputes every new `@Published` property above for the current `selectedPeriod`.
    /// Also refreshes today / yesterday transaction lists.
    func refreshAll() {
        let defaults = UserDefaults.appGroup
        // Missing keys have to fall back the same way `@AppStorage` does:
        // `bool(forKey:)` answers false for an absent key, which silently hid
        // the cents on the today/yesterday lists.
        showCents = defaults.object(forKey: "showCents") as? Bool ?? true
        currency = AppBaseCurrency.code(in: defaults)
        currencySymbol = Locale.appCurrencySymbol(forCurrencyCode: currency)

        // Net worth is point-in-time and lives on the account view model.
        // A direct refresh (tab appearance, period change) does not go through
        // DataRefreshCenter, so load here instead of showing a stale snapshot.
        let accounts = AccountViewModel.shared
        accounts.load()
        netWorth = accounts.netWorth
        totalAssets = accounts.totalAssets
        totalDebt = accounts.totalDebt

        let (periodStart, periodEnd) = getPeriodDateRange(for: selectedPeriod)
        let all = bookScopedTransactions()
        // Future-dated rows are "upcoming": Log lists them separately, the
        // budget ignores them, and the totals here must too — otherwise one
        // planned expense changes this period's spend, share and average.
        let now = Date.now
        let inPeriod = all.filter { txn in
            guard let date = txn.date else { return false }
            return date >= periodStart && date < periodEnd && date <= now
        }
        // `spendBaseAmount` is negative on a refund row, so money given back
        // reduces the period it arrived in without ever touching income.
        let spent = Money.sum(inPeriod.map(\.spendBaseAmount))
        let inc = Money.sum(inPeriod.filter(\.countsAsIncome).map(\.wrappedBaseAmount))
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
            divisor = AppPeriod.dayCount(in: (periodStart, periodEnd),
                                         calendar: configuredCalendar)
        }
        periodAverage = Money.double(abs(net) / Decimal(max(1, divisor)))
        periodAverageSpend = Money.double(spent / Decimal(max(1, divisor)))

        periodDateRangeText = getDateRangeText(for: selectedPeriod)

        barChartData = getBarChartData(for: selectedPeriod)
        categoryBreakdown = getCategoryBreakdown(for: selectedPeriod)
        // Same window as the totals above: `inPeriod` already drops future
        // rows, so a planned purchase never enters the merchant ranking.
        merchantBreakdown = MerchantSummary.breakdown(of: inPeriod)

        let cal = configuredCalendar
        let today = cal.startOfDay(for: .now)
        let tomorrow = cal.date(byAdding: .day, value: 1, to: today) ?? today
        let yesterday = cal.date(byAdding: .day, value: -1, to: today) ?? today

        let todayTxns = inPeriod
            .filter(\.countsInTotals)
            .filter { ($0.date ?? .distantPast) >= today && ($0.date ?? .distantPast) < tomorrow }
            .sorted { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
        todayTransactions = todayTxns
        todayTotal = Money.double(Money.sum(todayTxns.map(\.signedBaseAmount)))

        let yesterdayTxns = inPeriod
            .filter(\.countsInTotals)
            .filter { ($0.date ?? .distantPast) >= yesterday && ($0.date ?? .distantPast) < today }
            .sorted { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
        yesterdayTransactions = yesterdayTxns
        yesterdayTotal = Money.double(Money.sum(yesterdayTxns.map(\.signedBaseAmount)))

        refreshPendingReimbursements(all)
    }

    /// Claims still owed to the user. The outstanding part is in the spend
    /// card, so this sheet only shows the money that could still come back.
    private func refreshPendingReimbursements(_ all: [TransactionModel]) {
        pendingReimbursements = all
            .filter(\.isPendingReimbursement)
            .sorted { $0.wrappedDate > $1.wrappedDate }
        pendingReimbursementTotal = Money.double(
            Money.sum(pendingReimbursements.map(\.unreimbursedBaseAmount)))
    }

    /// Bar-chart buckets for the period. Week: 7 daily buckets, single-letter M T W T F S S labels.
    /// Month: `count` daily buckets matching the actual days in the period (28/29/30/31),
    /// every 7th day labelled (1, 8, 15, 22, 29). Year: 12 monthly buckets.
    func getBarChartData(for period: Int) -> [BarChartPoint] {
        let cal = configuredCalendar
        let (start, _) = getPeriodDateRange(for: period)
        let all = bookScopedTransactions()

        let count: Int
        let step: Calendar.Component
        let weekdayLetters = cal.veryShortWeekdaySymbols   // ["S","M","T","W","T","F","S"]
        switch period {
        case 1: count = 7; step = .day
        case 3: count = 12; step = .month
        default:
            // Match the period's actual day count (28/29/30/31, and 30/31 for a
            // shifted month start), not a hardcoded 30.
            count = AppPeriod.dayCount(in: getPeriodDateRange(for: period), calendar: cal)
            step = .day
        }

        var result = [BarChartPoint]()
        var cursor = start
        let monthLetters = cal.veryShortMonthSymbols      // ["J","F","M",...]
        for index in 0..<count {
            let next = cal.date(byAdding: step, value: 1, to: cursor) ?? cursor
            // Clamped at zero: Swift Charts' y-axis starts at 0, and a
            // refund-heavy day would otherwise draw a negative bar. The
            // period total above stays net.
            let sum = Money.sum(all
                .filter {
                    guard let date = $0.date else { return false }
                    return date >= cursor && date < next && date <= .now
                }
                .map { max(0, $0.spendBaseAmount) })

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
        let txns = bookScopedTransactions().filter { txn in
            guard let date = txn.date, let category = txn.category else { return false }
            guard txn.countsAsSpend || txn.isRefund else { return false }
            return date >= periodStart && date < periodEnd && date <= .now && !category.income
                && BookScope.matches(category.bookID, selected: BookState.shared.currentID)
        }
        var amounts = [UUID: Decimal]()
        var categories = [UUID: CategoryModel]()
        for txn in txns {
            guard let category = txn.category else { continue }
            amounts[category.id, default: 0] += Money.cents(txn.spendBaseAmount)
            categories[category.id] = category
        }
        let total = amounts.values.reduce(Decimal.zero, +)
        guard total > 0 else { return [] }
        let entries: [PowerCategory] = amounts.compactMap { (id, amount) in
            // A category whose purchases were fully refunded nets to zero (or
            // below, if a refund arrived without its purchase in this period);
            // it has no share of spend to show.
            guard let cat = categories[id], amount > 0 else { return nil }
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
}
