//
//  MoneyFormattingTests.swift
//  SmartBudTests
//
//  One formatter renders every amount in the app (log rows, insights,
//  budget day totals, `SBAmountText`). These pin the behaviour that used to
//  differ between those call sites.
//

import Testing
import Foundation

@Suite("MoneyFormatting")
struct MoneyFormattingTests {

    private let usLocale = Locale(identifier: "en_US")

    @Test("Currency symbol and two decimals")
    func withCents() {
        #expect(Money.format(12.3, currencyCode: "USD", locale: usLocale) == "$12.30")
    }

    @Test("Cents hidden")
    func withoutCents() {
        #expect(Money.format(1234.4, currencyCode: "USD", showsCents: false, locale: usLocale) == "$1,234")
    }

    @Test("Forced sign always follows the passed flag, not the value")
    func forcedSign() {
        #expect(Money.format(-12.3, currencyCode: "USD", plus: true, locale: usLocale) == "+$12.30")
        #expect(Money.format(12.3, currencyCode: "USD", plus: false, locale: usLocale) == "-$12.30")
    }

    @Test("No forced sign renders the magnitude")
    func magnitude() {
        #expect(Money.format(-12.3, currencyCode: "USD", locale: usLocale) == "$12.30")
    }

    @Test("Zero with a forced plus")
    func zeroSigned() {
        #expect(Money.format(0.0, currencyCode: "USD", plus: true, locale: usLocale) == "+$0.00")
    }

    @Test("Binary float tail is rounded before formatting")
    func roundsBinaryNoise() {
        #expect(Money.format(12.299_999_999, currencyCode: "USD", locale: usLocale) == "$12.30")
    }

    @Test("Decimal sums stay exact")
    func decimalSum() {
        let sum = Decimal(string: "0.1")! + Decimal(string: "0.2")!
        #expect(Money.format(sum, currencyCode: "USD", locale: usLocale) == "$0.30")
    }

    @Test("Non-dollar currencies use the selected locale's symbol")
    func otherCurrencies() {
        #expect(Money.format(12.3, currencyCode: "CNY",
                             locale: Locale(identifier: "zh_CN")) == "¥12.30")
    }
}
