//
//  DeepLinkTests.swift
//  SmartBudTests
//
//  URL parsing for `smartbud://add` and the x-callback-url reply URLs.
//

import Testing
import Foundation

@Suite("DeepLinkRequest")
struct DeepLinkRequestTests {

    private func link(_ string: String) -> DeepLinkRequest? {
        DeepLinkRequest(url: URL(string: string)!)
    }

    @Test("Amount, note and category are parsed")
    func parsesAdd() throws {
        let request = try #require(link(
            "smartbud://add?amount=12.5&type=expense&category=%E9%A4%90%E9%A5%AE&note=lunch"))
        #expect(request.action == .add)
        #expect(request.amount == 12.5)
        #expect(request.isIncome == false)
        #expect(request.categoryName == "餐饮")
        #expect(request.note == "lunch")
    }

    @Test("Type income flips the flag")
    func parsesIncome() throws {
        let request = try #require(link("smartbud://add?amount=100&type=income"))
        #expect(request.isIncome)
    }

    @Test("A comma decimal separator is accepted")
    func acceptsCommaDecimal() throws {
        let request = try #require(link("smartbud://add?amount=12%2C5"))
        #expect(request.amount == 12.5)
    }

    @Test("Missing or zero amounts are rejected")
    func rejectsInvalidAmount() throws {
        #expect(try #require(link("smartbud://add?note=x")).amount == nil)
        #expect(try #require(link("smartbud://add?amount=0")).amount == nil)
        #expect(try #require(link("smartbud://add?amount=abc")).amount == nil)
    }

    @Test("Amounts above the entry cap are clamped")
    func clampsLargeAmount() throws {
        let request = try #require(link("smartbud://add?amount=999999999"))
        #expect(request.amount == Money.maxAmount)
    }

    @Test("Reimbursement and discount flags/values are read")
    func parsesExtras() throws {
        let request = try #require(link(
            "smartbud://add?amount=50&reimbursable=1&discount=5"))
        #expect(request.isReimbursable)
        #expect(request.discount == 5)
    }

    @Test("Date is parsed as yyyy-MM-dd")
    func parsesDate() throws {
        let request = try #require(link("smartbud://add?amount=1&date=2026-03-05"))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let components = calendar.dateComponents([.year, .month, .day], from: request.date)
        #expect(components.year == 2026)
        #expect(components.month == 3)
        #expect(components.day == 5)
    }

    @Test("Tab routes resolve to the home tabs")
    func parsesTabs() throws {
        #expect(try #require(link("smartbud://open?tab=insights")).tab == "Insights")
        #expect(try #require(link("smartbud://insights")).tab == "Insights")
        #expect(try #require(link("smartbud://budget")).tab == "Budget")
        #expect(try #require(link("smartbud://open?tab=unknown")).tab == nil)
    }

    @Test("Callbacks are captured")
    func parsesCallbacks() throws {
        let request = try #require(link(
            "smartbud://add?amount=1&x-success=shortcuts%3A%2F%2Fsuccess&x-error=shortcuts%3A%2F%2Ferror"))
        #expect(request.callbackSuccess?.absoluteString == "shortcuts://success")
        #expect(request.callbackError?.absoluteString == "shortcuts://error")
    }

    @Test("Result URLs keep the base query")
    func buildsResultURL() throws {
        let base = URL(string: "shortcuts://callback?done=1")!
        let url = try #require(DeepLinkRequest.resultURL(
            base, items: [URLQueryItem(name: "id", value: "ABC")]))
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        #expect(components.queryItems?.contains(URLQueryItem(name: "done", value: "1")) == true)
        #expect(components.queryItems?.contains(URLQueryItem(name: "id", value: "ABC")) == true)
    }

    @Test("Foreign schemes and hosts are ignored")
    func rejectsForeignURL() {
        #expect(link("https://example.com/add?amount=1") == nil)
        #expect(link("smartbud://unknown?amount=1") == nil)
    }

    @Test("Search keeps its query")
    func parsesSearch() throws {
        let request = try #require(link("smartbud://search?q=coffee"))
        #expect(request.action == .search)
        #expect(request.searchQuery == "coffee")
    }
}
