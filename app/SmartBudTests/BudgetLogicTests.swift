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
