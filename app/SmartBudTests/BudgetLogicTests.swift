//
//  BudgetLogicTests.swift
//  SmartBudTests
//
//  Unit tests for the pure budget rollover / recurrence arithmetic in
//  app/smartbud/Logic/BudgetLogic.swift. The same source file is compiled
//  directly into this test bundle (no app-host), so no import is needed.
//

import Testing
import Foundation

@Suite("BudgetRollover")
struct BudgetRolloverTests {

    private let calendar = Calendar(identifier: .gregorian)

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day,
                                           hour: 0, minute: 0, second: 0))!
    }

    @Test("Invalid type returns nil (endDate == startDate, must not advance)")
    func invalidTypeReturnsNil() {
        #expect(BudgetRollover.roll(startDate: date(2026, 1, 1), type: 0,
                                    now: date(2026, 6, 1)) == nil)
        #expect(BudgetRollover.roll(startDate: date(2026, 1, 1), type: 5,
                                    now: date(2026, 6, 1)) == nil)
    }

    @Test("Monthly budget rolls to the current period")
    func monthlyRoll() {
        let start = BudgetRollover.roll(startDate: date(2026, 1, 1), type: 3,
                                        now: date(2026, 3, 15))
        #expect(start == date(2026, 3, 1))
    }

    @Test("Current period is left untouched")
    func currentPeriodUntouched() {
        let start = date(2026, 3, 1)
        let rolled = BudgetRollover.roll(startDate: start, type: 3,
                                         now: date(2026, 3, 15))
        #expect(rolled == start) // Apr 1 > Mar 15, no roll
    }

    @Test("Daily budget rolls day by day")
    func dailyRoll() {
        let start = BudgetRollover.roll(startDate: date(2026, 3, 1), type: 1,
                                        now: date(2026, 3, 4))
        #expect(start == date(2026, 3, 4))
    }

    @Test("Weekly budget rolls in 7-day steps")
    func weeklyRoll() {
        let start = BudgetRollover.roll(startDate: date(2026, 3, 1), type: 2,
                                        now: date(2026, 3, 20))
        #expect(start == date(2026, 3, 15)) // 1 -> 8 -> 15 (22 > 20, stop)
    }

    @Test("Yearly budget rolls in year steps")
    func yearlyRoll() {
        let start = BudgetRollover.roll(startDate: date(2020, 6, 1), type: 4,
                                        now: date(2026, 3, 1))
        #expect(start == date(2025, 6, 1))
    }

    @Test("Very old start date terminates quickly (regression: former infinite loop)")
    func ancientStartDateTerminates() {
        let start = BudgetRollover.roll(startDate: date(1970, 1, 1), type: 3,
                                        now: date(2026, 3, 15))
        #expect(start != nil)
        // Result must be within one period of `now`.
        let next = calendar.date(byAdding: .month, value: 1, to: start!)
        #expect(next! > date(2026, 3, 15))
    }
}

@Suite("Recurrence")
struct RecurrenceTests {

    private let calendar = Calendar(identifier: .gregorian)

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day,
                                           hour: 0, minute: 0, second: 0))!
    }

    @Test("Zero or negative coefficient returns nil (regression: former infinite loop)")
    func zeroCoefficientReturnsNil() {
        let day = date(2026, 3, 1)
        #expect(Recurrence.nextOccurrence(after: day, type: 1, coefficient: 0) == nil)
        #expect(Recurrence.nextOccurrence(after: day, type: 2, coefficient: 0) == nil)
        #expect(Recurrence.nextOccurrence(after: day, type: 3, coefficient: 0) == nil)
        #expect(Recurrence.nextOccurrence(after: day, type: 1, coefficient: -2) == nil)
    }

    @Test("Unknown type returns nil")
    func unknownTypeReturnsNil() {
        let day = date(2026, 3, 1)
        #expect(Recurrence.nextOccurrence(after: day, type: 0, coefficient: 1) == nil)
        #expect(Recurrence.nextOccurrence(after: day, type: 4, coefficient: 1) == nil)
    }

    @Test("Daily recurrence advances by N days")
    func dailyNext() {
        let next = Recurrence.nextOccurrence(after: date(2026, 3, 1), type: 1, coefficient: 3)
        #expect(next == date(2026, 3, 4))
    }

    @Test("Weekly recurrence advances by N weeks")
    func weeklyNext() {
        let next = Recurrence.nextOccurrence(after: date(2026, 3, 1), type: 2, coefficient: 2)
        #expect(next == date(2026, 3, 15))
    }

    @Test("Monthly recurrence advances by N months")
    func monthlyNext() {
        let next = Recurrence.nextOccurrence(after: date(2026, 1, 31), type: 3, coefficient: 1)
        // Jan 31 + 1 month clamps to Feb 28 in a non-leap year.
        #expect(next == date(2026, 2, 28))
    }
}

@Suite("Account balances")
struct AccountBalanceTests {
    @Test("Opening balance with no transactions stays put")
    func openingOnly() {
        #expect(AccountBalance.current(opening: 120, transactions: []) == 120)
    }

    @Test("Expenses subtract and income adds")
    func mixedTransactions() {
        let balance = AccountBalance.current(opening: 100, transactions: [
            (amount: 30, income: false, isRefund: false),
            (amount: 50, income: true, isRefund: false)
        ])
        #expect(balance == 120)
    }

    @Test("Overdraft is negative, not clamped")
    func negativeBalance() {
        #expect(AccountBalance.current(opening: 10, transactions: [(amount: 35, income: false, isRefund: false)]) == -25)
    }

    @Test("Transfers move money without touching income or spend")
    func transfersMoveMoney() {
        let source = AccountBalance.current(
            opening: 500, transactions: [], transfersIn: 0, transfersOut: 120)
        let destination = AccountBalance.current(
            opening: 0, transactions: [], transfersIn: 120, transfersOut: 0)
        #expect(source == 380)
        #expect(destination == 120)
        #expect(source + destination == 500)
    }
}

@Suite("Currency conversion")
struct CurrencyConversionTests {
    private let rates = ["CNY": 0.19, "USD": 1.0]

    @Test("Base currency converts 1:1")
    func baseIsOne() {
        #expect(CurrencyConversion.rate(for: "SGD", base: "SGD", rates: rates) == 1)
        #expect(CurrencyConversion.convert(50, from: "SGD", to: "SGD", rates: rates) == 50)
    }

    @Test("Foreign currency multiplies by its rate")
    func convertsWithRate() {
        #expect(CurrencyConversion.convert(100, from: "CNY", to: "SGD", rates: rates) == 19)
    }

    @Test("Unknown currency falls back to 1:1 instead of zero")
    func missingRateFallsBack() {
        #expect(CurrencyConversion.rate(for: "JPY", base: "SGD", rates: rates) == 1)
    }

    @Test("Non-positive or non-finite rates are ignored")
    func badRatesIgnored() {
        #expect(CurrencyConversion.rate(for: "CNY", base: "SGD", rates: ["CNY": 0]) == 1)
        #expect(CurrencyConversion.rate(for: "CNY", base: "SGD", rates: ["CNY": .infinity]) == 1)
    }

    @Test("Rounded conversion keeps two decimals")
    func roundsToCents() {
        let converted = CurrencyConversion.convertRounded(33.33, from: "CNY", to: "SGD",
                                                         rates: ["CNY": 0.1937])
        // Float maths: compare with a small tolerance rather than bit equality.
        #expect(abs(converted - 6.46) < 0.0001)
    }
}

@Suite("Exchange rate service")
struct ExchangeRateServiceTests {
    private let sample = Data("""
    {"amount":1.0,"base":"SGD","date":"2026-10-21","rates":{"CNY":5.26,"USD":0.74}}
    """.utf8)

    @Test("API quotes are inverted to 'one unit = base'")
    func invertsRates() throws {
        let rates = try ExchangeRateService.invertedRates(from: sample)
        #expect(abs((rates["CNY"] ?? 0) - 1 / 5.26) < 0.000001)
        #expect(abs((rates["USD"] ?? 0) - 1 / 0.74) < 0.000001)
    }

    @Test("Malformed payloads throw instead of returning empty rates")
    func rejectsGarbage() {
        let garbage = Data("not json".utf8)
        #expect(throws: ExchangeRateService.ServiceError.self) {
            try ExchangeRateService.invertedRates(from: garbage)
        }
    }

    @Test("Non-positive quotes are dropped")
    func dropsBadQuotes() throws {
        let data = Data("""
        {"amount":1.0,"base":"SGD","date":"2026-10-21","rates":{"CNY":0,"USD":0.74}}
        """.utf8)
        let rates = try ExchangeRateService.invertedRates(from: data)
        #expect(rates["CNY"] == nil)
        #expect(rates["USD"] != nil)
    }
}

@Suite("Cross-currency transfers")
struct CrossCurrencyTransferTests {
    @Test("Received amount is what lands in the destination account")
    func receivedAmount() {
        let transfer = TransferModel(amount: 100, destinationAmount: 526)
        #expect(transfer.receivedAmount == 526)
        #expect(abs((transfer.impliedRate ?? 0) - 5.26) < 0.0001)
    }

    @Test("Same-currency transfers keep the legacy shape")
    func sameCurrency() {
        let transfer = TransferModel(amount: 100)
        #expect(transfer.receivedAmount == 100)
        #expect(transfer.impliedRate == nil)
    }

    @Test("Balances use the received amount, not the sent amount")
    func balancesDiffer() {
        let source = AccountBalance.current(opening: 1000, transactions: [], transfersOut: 100)
        let destination = AccountBalance.current(opening: 0, transactions: [], transfersIn: 526)
        #expect(source == 900)
        #expect(destination == 526)
    }
}

// MARK: - Budget forecast (TELE-22)

@Suite("Budget forecast")
struct BudgetForecastTests {
    private let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        return cal
    }()

    private func date(_ day: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 4, day: day,
                                           hour: hour, minute: 0, second: 0))!
    }

    /// April 2026 has 30 days: 15 normal days of 10 plus one 1,000 one-off.
    private var fixedDataset: [BudgetForecastEntry] {
        (1...15).map { BudgetForecastEntry(date: date($0), spend: 10) }
            + [BudgetForecastEntry(date: date(10, hour: 18), spend: 1000)]
    }

    @Test("30-day dataset: hand-computed projection and outlier exclusion")
    func projectionWithOutlierExcluded() {
        let result = BudgetForecast.estimate(
            entries: fixedDataset, budget: 200,
            periodStart: date(1, hour: 0), periodEnd: date(30, hour: 0).addingTimeInterval(86_400),
            now: date(16), calendar: calendar)
        #expect(result?.spent == 150)
        #expect(result?.projectedSpend == 281.25)   // 150 / 16 * 30
        #expect(result?.overspend == 81.25)         // 281.25 - 200
        #expect(result?.elapsedDays == 16)
        #expect(result?.totalDays == 30)
        #expect(result?.excludedOutlierCount == 1)
    }

    @Test("Outlier switch off keeps the large entry in the projection")
    func projectionWithOutlierIncluded() {
        let result = BudgetForecast.estimate(
            entries: fixedDataset, budget: 200,
            periodStart: date(1, hour: 0), periodEnd: date(30, hour: 0).addingTimeInterval(86_400),
            excludeOutliers: false, now: date(16), calendar: calendar)
        #expect(result?.spent == 1150)
        #expect(result?.projectedSpend == 2156.25)  // 1150 / 16 * 30
        #expect(result?.overspend == 1956.25)
        #expect(result?.excludedOutlierCount == 0)
    }

    @Test("No spend in the middle of the month projects zero, never divides by zero")
    func noSpendMidMonth() {
        let result = BudgetForecast.estimate(
            entries: [], budget: 200,
            periodStart: date(1, hour: 0), periodEnd: date(30, hour: 0).addingTimeInterval(86_400),
            now: date(16), calendar: calendar)
        #expect(result?.projectedSpend == 0)
        #expect(result?.overspend == 0)
        #expect(result?.elapsedDays == 16)
    }

    @Test("Feature switch off produces no forecast at all")
    func disabledReturnsNil() {
        #expect(BudgetForecast.estimate(
            entries: fixedDataset, budget: 200,
            periodStart: date(1, hour: 0), periodEnd: date(30, hour: 0).addingTimeInterval(86_400),
            enabled: false, now: date(16), calendar: calendar) == nil)
    }

    @Test("On the last day the projection equals actual spend")
    func lastDayEqualsActual() {
        let result = BudgetForecast.estimate(
            entries: fixedDataset, budget: 200,
            periodStart: date(1, hour: 0), periodEnd: date(30, hour: 0).addingTimeInterval(86_400),
            now: date(30, hour: 23), calendar: calendar)
        #expect(result?.elapsedDays == 30)
        #expect(result?.projectedSpend == 150)
        #expect(result?.overspend == 0)
    }
}

// MARK: - Subscription detection (TELE-22)

@Suite("Subscription detection")
struct SubscriptionDetectionTests {
    private let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        return cal
    }()

    private struct Group {
        let key: String
        let rows: [SubscriptionEntry]
        let isPositive: Bool
    }

    private var anchor: Date {
        calendar.date(from: DateComponents(year: 2027, month: 3, day: 5,
                                           hour: 12, minute: 0, second: 0))!
    }

    private var nowDate: Date {
        calendar.date(from: DateComponents(year: 2027, month: 4, day: 1,
                                           hour: 12, minute: 0, second: 0))!
    }

    private func monthDate(_ offset: Int, dayShift: Int = 0) -> Date {
        var components = DateComponents()
        components.month = offset
        components.day = dayShift
        return calendar.date(byAdding: components, to: anchor)!
    }

    private func dayDate(_ offset: Int) -> Date {
        calendar.date(byAdding: .day, value: offset, to: anchor)!
    }

    private func rows(_ key: String, amounts: [Double], dates: [Date],
                      recurring: Bool = false) -> [SubscriptionEntry] {
        zip(amounts, dates).map { amount, date in
            SubscriptionEntry(id: UUID(), merchantKey: key, merchantName: key,
                              amount: amount, date: date, isRecurring: recurring)
        }
    }

    private func group(_ key: String, _ amounts: [Double],
                       months: [Int], shifts: [Int] = [],
                       recurring: Bool = false, positive: Bool) -> Group {
        let dates = months.enumerated().map { monthDate($0.element,
                                                         dayShift: shifts.indices.contains($0.offset)
                                                             ? shifts[$0.offset] : 0) }
        return Group(key: key, rows: rows(key, amounts: amounts, dates: dates,
                                          recurring: recurring), isPositive: positive)
    }

    /// Ten real subscription shapes and ten lookalikes. The confusion matrix
    /// is printed so the PR can quote actual counts instead of a percentage.
    private var fixture: [Group] {
        [
            group("p1_month_plain", [30, 30, 30], months: [-2, -1, 0], positive: true),
            group("p2_month_jitter", [29.5, 30.4, 30], months: [-2, -1, 0],
                  shifts: [-1, 1, 0], positive: true),
            group("p3_month_four", [12, 12.5, 11.8, 12.1], months: [-3, -2, -1, 0], positive: true),
            group("p4_month_noise", [75, 20, 20, 20, 20, 20], months: [-5, -4, -3, -2, -1, 0],
                  positive: true),
            group("p5_quarter_plain", [90, 90, 90], months: [-6, -3, 0], positive: true),
            group("p6_quarter_jitter", [88, 92, 90.5], months: [-6, -3, 0],
                  shifts: [2, -1, 0], positive: true),
            group("p7_quarter_four", [45, 45.5, 44.8, 45.2], months: [-9, -6, -3, 0], positive: true),
            group("p8_year_plain", [360, 360, 360], months: [-24, -12, 0], positive: true),
            group("p9_year_jitter", [355, 366, 360], months: [-24, -12, 0],
                  shifts: [0, 1, -1], positive: true),
            group("p10_month_long", [15, 15.2, 14.9, 15.1, 15], months: [-4, -3, -2, -1, 0],
                  positive: true),

            group("n1_two_only", [20, 20], months: [-1, 0], positive: false),
            group("n2_irregular", [20, 20, 20], months: [-6, -5, -1], positive: false),
            group("n3_amount_drift", [20, 25, 32], months: [-2, -1, 0], positive: false),
            Group(key: "n4_weekly",
                  rows: rows("n4_weekly", amounts: [10, 10, 10, 10],
                             dates: [-21, -14, -7, 0].map(dayDate)), isPositive: false),
            group("n5_already_recurring", [30, 30, 30], months: [-2, -1, 0],
                  recurring: true, positive: false),
            group("", [30, 30, 30], months: [-2, -1, 0], positive: false),
            group("n7_bimonthly", [30, 30, 30], months: [-4, -2, 0], positive: false),
            group("n8_amount_spread", [20, 20, 26], months: [-2, -1, 0], positive: false),
            group("n9_stale_monthly", [30, 30, 30], months: [-30, -29, -28], positive: false),
            group("n10_adopted", [30, 30, 30], months: [-2, -1, 0], positive: false)
        ]
    }

    @Test("20 groups: recall >= 80%, false positives <= 10%")
    func confusionMatrix() {
        let groups = fixture
        let now = nowDate
        let detected = Set(SubscriptionDetector.detect(
            groups.flatMap(\.rows), now: now,
            excluding: ["n10_adopted"], calendar: calendar).map(\.merchantKey))

        let tp = groups.filter { $0.isPositive && detected.contains($0.key) }.count
        let fn = groups.filter { $0.isPositive && !detected.contains($0.key) }.count
        let fp = groups.filter { !$0.isPositive && detected.contains($0.key) }.count
        let tn = groups.filter { !$0.isPositive && !detected.contains($0.key) }.count
        print("TELE-22 subscription confusion matrix: TP=\(tp) FN=\(fn) FP=\(fp) TN=\(tn)")

        #expect(groups.count == 20)
        #expect(Double(tp) / Double(tp + fn) >= 0.8)
        #expect(Double(fp) / Double(fp + tn) <= 0.1)
        #expect(tp == 10)  // deterministic fixture: every real shape is found
        #expect(fp == 0)   // and no lookalike is mislabelled
    }

    @Test("Cadence maps to the recurring coefficient used by the ledger")
    func cadences() {
        let groups = fixture
        let now = nowDate
        let suggestions = SubscriptionDetector.detect(groups.flatMap(\.rows),
                                                      now: now, calendar: calendar)
        let byKey = Dictionary(uniqueKeysWithValues: suggestions.map { ($0.merchantKey, $0) })
        #expect(byKey["p1_month_plain"]?.cadence.months == 1)
        #expect(byKey["p5_quarter_plain"]?.cadence.months == 3)
        #expect(byKey["p8_year_plain"]?.cadence.months == 12)
        #expect(byKey["p10_month_long"]?.occurrenceCount == 5)
    }

    @Test("A stopped merchant is not suggested even with a stable history")
    func staleMerchantIsRejected() {
        let stale = group("stale", [30, 30, 30], months: [-30, -29, -28],
                          positive: false).rows
        let fresh = group("fresh", [30, 30, 30], months: [-2, -1, 0],
                          positive: true).rows
        #expect(SubscriptionDetector.detect(stale, now: nowDate, calendar: calendar).isEmpty)
        #expect(SubscriptionDetector.detect(fresh, now: nowDate, calendar: calendar).count == 1)
    }
}

// MARK: - Budget alert policy (TELE-22)

@Suite("Budget alerts")
struct BudgetAlertTests {
    private let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        return cal
    }()

    private func date(_ day: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 4, day: day,
                                           hour: 12, minute: 0, second: 0))!
    }

    private var snapshot: BudgetAlertSnapshot {
        BudgetAlertSnapshot(budgetID: "main", periodKey: "2026-04-01",
                            budget: 200, spent: 170,
                            forecast: BudgetForecast.Result(spent: 170,
                                                            projectedSpend: 260,
                                                            overspend: 60,
                                                            elapsedDays: 16,
                                                            totalDays: 30,
                                                            excludedOutlierCount: 0))
    }

    @Test("Feature switch off sends nothing and leaves history untouched")
    func disabledSendsNothing() {
        let result = BudgetAlertEvaluator.requests(for: [snapshot], enabled: false,
                                                   now: date(16),
                                                   frequency: .oncePerPeriod,
                                                   history: [:], calendar: calendar)
        #expect(result.requests.isEmpty)
        #expect(result.history.isEmpty)
    }

    @Test("80 percent and forecast overspend fire once per budget period")
    func oncePerPeriod() {
        let first = BudgetAlertEvaluator.requests(for: [snapshot], enabled: true,
                                                  now: date(16),
                                                  frequency: .oncePerPeriod,
                                                  history: [:], calendar: calendar)
        #expect(first.requests.map(\.kind) == [.usage80, .projectedOverspend])
        let second = BudgetAlertEvaluator.requests(for: [snapshot], enabled: true,
                                                   now: date(20),
                                                   frequency: .oncePerPeriod,
                                                   history: first.history, calendar: calendar)
        #expect(second.requests.isEmpty)
        #expect(second.history == first.history)
    }

    @Test("Daily frequency allows one more alert on a later day")
    func dailyFrequency() {
        let first = BudgetAlertEvaluator.requests(for: [snapshot], enabled: true,
                                                  now: date(16),
                                                  frequency: .daily,
                                                  history: [:], calendar: calendar)
        #expect(first.requests.count == 2)
        let sameDay = BudgetAlertEvaluator.requests(for: [snapshot], enabled: true,
                                                    now: date(16),
                                                    frequency: .daily,
                                                    history: first.history, calendar: calendar)
        #expect(sameDay.requests.isEmpty)
        let nextDay = BudgetAlertEvaluator.requests(for: [snapshot], enabled: true,
                                                    now: date(17),
                                                    frequency: .daily,
                                                    history: first.history, calendar: calendar)
        #expect(nextDay.requests.count == 2)
    }
}
