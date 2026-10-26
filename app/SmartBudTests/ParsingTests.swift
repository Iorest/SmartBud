//
//  ParsingTests.swift
//  SmartBudTests
//
//  Text and receipt parsing feeds the amount straight into the entry form, so
//  a wrong number here becomes a wrong ledger without the user noticing.
//

import Testing
import Foundation

@Suite("Text parsing")
struct ExpenseTextParserTests {

    @Test("A date in the phrase is not taken as the amount")
    func ignoresDate() throws {
        let parsed = try #require(ExpenseTextParser.parse("10月25日 午饭 35"))
        #expect(parsed.amount == 35)
    }

    @Test("A counter is not taken as the amount")
    func ignoresCounter() throws {
        let parsed = try #require(ExpenseTextParser.parse("打车 3 个人 88"))
        #expect(parsed.amount == 88)
    }

    @Test("A labelled amount wins over an earlier number")
    func labelledAmount() throws {
        let parsed = try #require(ExpenseTextParser.parse("2 杯咖啡 实付 35.50 元"))
        #expect(parsed.amount == Decimal(string: "35.5"))
    }

    @Test("Thousands separators are one number")
    func thousandsSeparator() throws {
        let parsed = try #require(ExpenseTextParser.parse("房租 ¥12,000"))
        #expect(parsed.amount == 12_000)
    }

    @Test("An amount above the pad's cap is refused")
    func refusesOverCap() {
        #expect(ExpenseTextParser.parse("工资 999999999") == nil)
    }
}

@Suite("Receipt parsing")
struct AlipayWechatParserTests {

    @Test("The labelled total beats the wallet balance")
    func ignoresBalanceLine() throws {
        let lines = [
            "微信支付",
            "当前状态 支付成功",
            "余额 ¥8,000.00",
            "实付 ¥1,234.56"
        ]
        let result = try #require(AlipayWechatParser().parse(lines: lines))
        #expect(result.amount == Decimal(string: "1234.56"))
        #expect(result.platform == .wechat)
    }

    @Test("A bare symbol amount keeps its thousands separator")
    func bareSymbolThousands() throws {
        let lines = ["支付宝", "账单详情", "¥12,000.00"]
        let result = try #require(AlipayWechatParser().parse(lines: lines))
        #expect(result.amount == 12_000)
    }

    @Test("A discount line is not the amount")
    func ignoresDiscountLine() throws {
        let lines = ["支付宝", "优惠 ¥5.00", "支付金额 ¥45.00"]
        let result = try #require(AlipayWechatParser().parse(lines: lines))
        #expect(result.amount == 45)
    }
}

@Suite("Import amount")
struct ImportAmountTests {

    @Test("A plain number parses")
    func plain() {
        #expect(ImportAmount.parse("12.50") == 12.5)
    }

    @Test("Currency symbols, thousands separators and units are ignored")
    func decorated() {
        #expect(ImportAmount.parse("$1,200.00") == 1200)
        #expect(ImportAmount.parse("12.50元") == 12.5)
        #expect(ImportAmount.parse("1,200.50") == 1200.50)
        #expect(ImportAmount.parse("USD 12.00") == 12)
    }

    @Test("Full-width digits and parentheses are understood")
    func fullWidthAndNegative() {
        #expect(ImportAmount.parse("１２．５０") == 12.5)
        #expect(ImportAmount.parse("(1,200.00)") == -1200)
    }

    @Test("Non-numbers and values above the cap are refused")
    func rejectsInvalid() {
        #expect(ImportAmount.parse("") == nil)
        #expect(ImportAmount.parse("lunch") == nil)
        #expect(ImportAmount.parse("1e400") == nil)
        #expect(ImportAmount.parse("999,999,999") == nil)
    }
}
