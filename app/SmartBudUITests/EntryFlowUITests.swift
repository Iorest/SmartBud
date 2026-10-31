//
//  EntryFlowUITests.swift
//  SmartBudUITests
//
//  Flow A — the entry path: number pad → category → save → ledger → stats.
//  Every assertion lands on a result (a row's amount, a stat total, the
//  amount read-out) rather than on "the screen is there": a case that only
//  opened a form would pass on a build that never writes anything.
//
//  Fixture: `launch()` seeds `UITestFixture` (餐饮 / 交通 / 工资, 现金 / 银行卡 /
//  人民币) into an in-memory store, so the numbers are absolute and repeatable.
//

import XCTest

@MainActor
final class EntryFlowUITests: SmartBudUITestCase {

    // MARK: - A1. Add an expense and see it in the ledger and the stats

    func testA1_addExpense_updatesStats() throws {
        let app = launch()

        openEntryForm(in: app)
        enterAmount("12.50", in: app)
        XCTAssertEqual(entryAmount(in: app) ?? -1, 12.50, accuracy: 0.001,
                       "The pad did not read back 12.50.\n\(app.debugDescription)")

        selectCategory("餐饮", in: app)
        // Choosing a category must not touch the amount.
        XCTAssertEqual(entryAmount(in: app) ?? -1, 12.50, accuracy: 0.001,
                       "The category picker cleared the amount.")

        saveEntry(in: app)

        waitForRowCount(1, in: app)
        assertNewestRowAmount("12.50", in: app)

        // The ledger's own summary card (net total for the period).
        let summary = require(app, AccessibilityID.logSummary)
        assertAmount(summary, equals: 12.50, "Log net total")

        // The stats screen is the number the user checks against their bank.
        select(.insights, in: app)
        assertAmount(require(app, AccessibilityID.insightsExpenseCard),
                     equals: 12.50, "Insights expenses")
        assertAmount(require(app, AccessibilityID.insightsIncomeCard),
                     equals: 0, "Insights income")
    }

    // MARK: - A1b. A second entry accumulates in the same statistic

    func testA1_secondExpenseAccumulatesInStats() throws {
        let app = launch()

        openEntryForm(in: app)
        enterAmount("12.50", in: app)
        selectCategory("餐饮", in: app)
        saveEntry(in: app)
        waitForRowCount(1, in: app)

        openEntryForm(in: app)
        enterAmount("7.50", in: app)
        selectCategory("交通", in: app)
        saveEntry(in: app)
        waitForRowCount(2, in: app)

        select(.insights, in: app)
        assertAmount(require(app, AccessibilityID.insightsExpenseCard),
                     equals: 20.00, "Insights expenses after two entries")
    }

    // MARK: - A2. Continuous entry keeps the category and clears the amount

    func testA2_continuousEntry_keepsCategoryClearsAmount() throws {
        let app = launch()
        enableContinuousEntry(in: app)

        openEntryForm(in: app)
        enterAmount("13", in: app)
        selectCategory("交通", in: app)

        let save = require(app, AccessibilityID.entrySave)
        waitUntilEnabled(save)
        save.tap()

        // The form stays open: the amount is cleared, the category is kept.
        XCTAssertEqual(element(app, AccessibilityID.entryAmount).waitForExistence(timeout: 10), true)
        XCTAssertEqual(entryAmount(in: app) ?? -1, 0, accuracy: 0.001,
                       "The amount was not cleared after a continuous save.\n\(app.debugDescription)")
        let categoryPill = element(app, AccessibilityID.entryCategoryButton)
        XCTAssertTrue(categoryPill.label.contains("交通"),
                      "The category was not kept for the next entry: \"\(categoryPill.label)\"")

        // Second entry in the same session.
        enterAmount("7", in: app)
        save.tap()
        waitForRowCount(2, in: app)

        let rows = app.buttons.matching(identifier: AccessibilityID.logRow)
        XCTAssertTrue(rows.element(boundBy: 0).label.contains("7"),
                      "Newest row is not the second entry: \"\(rows.element(boundBy: 0).label)\"")
        XCTAssertTrue(rows.element(boundBy: 1).label.contains("13"),
                      "Second row is not the first entry: \"\(rows.element(boundBy: 1).label)\"")
    }

    /// Settings → Number Entry Method → Save and Continue. Uses the real
    /// screen (the toggle writes the same App Storage key the form reads), so
    /// a broken route fails here instead of silently leaving the form in
    /// dismiss-on-save mode.
    private func enableContinuousEntry(in app: XCUIApplication) {
        select(.settings, in: app)
        tapSettingRow(AccessibilityID.settingsRow("numberEntry"), in: app)
        let toggle = require(app, AccessibilityID.settingsContinuousEntryToggle)
        if toggle.value as? String != "1" { toggle.tap() }
        XCTAssertEqual(toggle.value as? String, "1",
                       "The Save and Continue toggle did not turn on.\n\(app.debugDescription)")
        require(app, AccessibilityID.settingsBack).tap()
        require(app, AccessibilityID.settingsRow("numberEntry"))
    }

    // MARK: - A3. Validation

    func testA3_zeroAmount_keepsSaveDisabled() throws {
        let app = launch()
        openEntryForm(in: app)

        let save = require(app, AccessibilityID.entrySave)
        XCTAssertFalse(save.isEnabled,
                       "Save is tappable with an empty amount.\n\(app.debugDescription)")

        // Even with a category chosen, 0 is not a valid amount.
        selectCategory("餐饮", in: app)
        XCTAssertFalse(require(app, AccessibilityID.entrySave).isEnabled,
                       "Save became tappable without an amount.")
        XCTAssertEqual(rowCount(in: app), 0, "Something was written without an amount.")
    }

    func testA3_missingCategory_blocksSaveAndExplains() throws {
        let app = launch()
        openEntryForm(in: app)
        enterAmount("25", in: app)

        let save = require(app, AccessibilityID.entrySave)
        waitUntilEnabled(save)
        save.tap()

        // The rejection must be explainable, not silent: the form stays open
        // and the toast says which field is missing.
        let toast = require(app, AccessibilityID.entryToast, timeout: 5)
        XCTAssertFalse(toast.label.isEmpty, "The rejection toast is empty.")
        XCTAssertTrue(toast.label.contains("Category"),
                      "The toast does not name the missing field: \"\(toast.label)\"")

        require(app, AccessibilityID.entrySave)
        XCTAssertEqual(rowCount(in: app), 0, "A rejected entry was written anyway.")
    }

    func testA3_amountCap_stopsAcceptingDigits() throws {
        let app = launch()
        openEntryForm(in: app)

        // One digit first: a positive control, so "nothing changes" cannot be
        // confused with "the pad never worked".
        require(app, AccessibilityID.padDigit(9)).tap()
        XCTAssertEqual(entryAmount(in: app) ?? -1, 9, accuracy: 0.001,
                       "The pad does not accept a single digit.")

        // Push well past `Money.maxAmount` (100,000,000).
        for _ in 0..<11 { element(app, AccessibilityID.padDigit(9)).tap() }
        let capped = element(app, AccessibilityID.entryAmount).label

        for _ in 0..<3 { element(app, AccessibilityID.padDigit(9)).tap() }
        XCTAssertEqual(element(app, AccessibilityID.entryAmount).label, capped,
                       "The pad kept appending digits past the cap.")
        XCTAssertLessThan(entryAmount(in: app) ?? .infinity, 100_000_000,
                          "The entered amount exceeded Money.maxAmount: \(capped)")
    }

    func testA3_incomeSideHidesExpenseCategoriesAndClearsSelection() throws {
        let app = launch()
        openEntryForm(in: app)
        enterAmount("10", in: app)
        selectCategory("餐饮", in: app)

        selectEntryType(income: true, in: app)
        // Flipping the side drops a category that no longer applies...
        let pill = element(app, AccessibilityID.entryCategoryButton)
        let cleared = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == %@", "Category"), object: pill)
        XCTAssertEqual(XCTWaiter().wait(for: [cleared], timeout: 10), .completed,
                       "Switching to income kept the expense category: \"\(pill.label)\"")

        // ...and the grid only offers income categories.
        require(app, AccessibilityID.entryCategoryButton).tap()
        XCTAssertTrue(categoryTile(named: "工资", in: app).waitForExistence(timeout: 10),
                      "Income category 工资 is not offered on the income side.")
        XCTAssertFalse(categoryTile(named: "餐饮", in: app).exists,
                       "Expense category 餐饮 is offered on the income side.")
    }

    // MARK: - A4. Discount and claim survive the round trip into the ledger

    func testA4_discountAndClaim_persistOnRow() throws {
        let app = launch()
        openEntryForm(in: app)
        enterAmount("20", in: app)
        selectCategory("餐饮", in: app)

        // Discount 5: the alert's field, then Done.
        require(app, AccessibilityID.entryDiscount).tap()
        let field = app.textFields[AccessibilityID.entryDiscountField].firstMatch
        let fallback = app.alerts.firstMatch.textFields.firstMatch
        let input = field.waitForExistence(timeout: 5) ? field : fallback
        XCTAssertTrue(input.exists, "The discount field never appeared.\n\(app.debugDescription)")
        input.tap()
        input.typeText("5")
        app.alerts.firstMatch.buttons["Done"].firstMatch.tap()

        // Claim: the chip toggles, no alert.
        let claim = require(app, AccessibilityID.entryClaim)
        claim.tap()
        XCTAssertTrue(claim.isSelected, "The claim chip did not turn on.")

        saveEntry(in: app)
        waitForRowCount(1, in: app)

        let row = app.buttons.matching(identifier: AccessibilityID.logRow).firstMatch
        XCTAssertTrue(row.label.contains("Discount"),
                      "The row lost the discount: \"\(row.label)\"")
        XCTAssertTrue(row.label.contains("Pending"),
                      "The row lost the pending claim: \"\(row.label)\"")
    }

    // MARK: - A4b. A future date lands in UPCOMING and stays out of the totals

    func testA4_futureDate_goesToUpcomingAndSkipsStats() throws {
        // The graphical date picker pages month by month and has no stable
        // anchors, so the future date arrives the way an automation would send
        // it: through the URL router (`-uiTestStore` + `DEEPLINK_URL`).
        let app = launch(environment: [
            "DEEPLINK_URL": "smartbud://add?amount=20&category=%E4%BA%A4%E9%80%9A&date=2027-01-05"
        ])

        waitForRowCount(1, in: app)
        require(app, AccessibilityID.logUpcomingHeader)
        assertNewestRowAmount("20", in: app)

        // Future money is not spend yet.
        assertAmount(require(app, AccessibilityID.logSummary), equals: 0, "Log net total")
        select(.insights, in: app)
        assertAmount(require(app, AccessibilityID.insightsExpenseCard),
                     equals: 0, "Insights expenses")
    }
}
