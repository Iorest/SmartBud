//
//  LedgerEditingUITests.swift
//  SmartBudUITests
//
//  Flow B — editing an existing row, and deleting one with the 6-second undo.
//  The undo case compares the row's *whole* label before and after, because the
//  regression it exists for is a partial restore (the amount came back, the
//  discount and the claim did not).
//

import XCTest

final class LedgerEditingUITests: SmartBudUITestCase {

    // MARK: - B5. Editing the amount moves the statistics with it

    func testB5_editAmount_updatesStats() throws {
        let app = launch()
        openEntryForm(in: app)
        enterAmount("12.50", in: app)
        selectCategory("餐饮", in: app)
        saveEntry(in: app)
        waitForRowCount(1, in: app)
        assertNewestRowAmount("12.50", in: app)

        openNewestRow(in: app)
        clearEntryAmount(in: app)
        enterAmount("30", in: app)
        XCTAssertEqual(entryAmount(in: app) ?? -1, 30, accuracy: 0.001,
                       "The edit form did not accept the new amount.")
        saveEntry(in: app)

        waitForRowCount(1, in: app)
        assertNewestRowAmount("30", in: app)
        select(.insights, in: app)
        assertAmount(require(app, AccessibilityID.insightsExpenseCard),
                     equals: 30, "Insights expenses after the edit")
    }

    // MARK: - B5b. Changing the side drops the category that no longer fits

    func testB5_switchToIncome_clearsCategoryAndMovesTheTotal() throws {
        let app = launch()
        openEntryForm(in: app)
        enterAmount("12.50", in: app)
        selectCategory("餐饮", in: app)
        saveEntry(in: app)
        waitForRowCount(1, in: app)

        openNewestRow(in: app)
        selectEntryType(income: true, in: app)

        let pill = element(app, AccessibilityID.entryCategoryButton)
        let cleared = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == %@", "Category"), object: pill)
        XCTAssertEqual(XCTWaiter().wait(for: [cleared], timeout: 10), .completed,
                       "Switching to income kept the expense category: \"\(pill.label)\"")
        XCTAssertFalse(element(app, AccessibilityID.entryDiscount).exists,
                       "An income row still offers the discount chip.")

        saveEntry(in: app)
        waitForRowCount(1, in: app)

        select(.insights, in: app)
        assertAmount(require(app, AccessibilityID.insightsExpenseCard),
                     equals: 0, "Insights expenses after switching to income")
        assertAmount(require(app, AccessibilityID.insightsIncomeCard),
                     equals: 12.50, "Insights income after switching to income")
    }

    // MARK: - B6. Delete then undo restores every field, not just the amount

    func testB6_deleteUndo_restoresAllFields() throws {
        let app = launch()
        openEntryForm(in: app)
        enterAmount("20", in: app)
        selectCategory("餐饮", in: app)
        selectAccount(named: "现金", in: app)

        // Discount 5 + claim, so the restored row has three things to lose.
        require(app, AccessibilityID.entryDiscount).tap()
        let field = app.textFields[AccessibilityID.entryDiscountField].firstMatch
        let fallback = app.alerts.firstMatch.textFields.firstMatch
        let input = field.waitForExistence(timeout: 5) ? field : fallback
        input.tap()
        input.typeText("5")
        app.alerts.firstMatch.buttons["Done"].firstMatch.tap()
        require(app, AccessibilityID.entryClaim).tap()

        saveEntry(in: app)
        waitForRowCount(1, in: app)

        let row = app.buttons.matching(identifier: AccessibilityID.logRow).firstMatch
        let before = row.label
        XCTAssertTrue(before.contains("Discount"), "Fixture row lost its discount: \(before)")
        XCTAssertTrue(before.contains("Pending"), "Fixture row lost its claim: \(before)")
        XCTAssertTrue(before.contains("现金"), "Fixture row lost its account: \(before)")

        swipeDelete(row, in: app)
        // The undo window is 6 s; tapping inside it must restore, not commit.
        require(app, AccessibilityID.logUndoButton, timeout: 5).tap()
        waitForRowCount(1, in: app)

        let restored = app.buttons.matching(identifier: AccessibilityID.logRow).firstMatch
        XCTAssertTrue(restored.waitForExistence(timeout: 10),
                      "Undo did not bring the row back.\n\(app.debugDescription)")
        XCTAssertEqual(restored.label, before,
                       "Undo restored a different row (fields were not all restored).")
    }

    // MARK: - Helpers

    /// Tapping a row opens it in the edit form.
    private func openNewestRow(in app: XCUIApplication,
                               file: StaticString = #filePath, line: UInt = #line) {
        let row = app.buttons.matching(identifier: AccessibilityID.logRow).firstMatch
        if !row.waitForExistence(timeout: 10) {
            XCTFail("No ledger row to open.\n\(app.debugDescription)", file: file, line: line)
            return
        }
        row.tap()
        require(app, AccessibilityID.entrySave, file: file, line: line)
    }
}
