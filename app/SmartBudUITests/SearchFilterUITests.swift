//
//  SearchFilterUITests.swift
//  SmartBudUITests
//
//  Flow G — search and the ledger filters. Two properties matter and both have
//  regressed before: search narrows the *current* filter instead of ignoring
//  it, and the type filter never shows balance adjustments (they are neither
//  income nor spend).
//

import XCTest

@MainActor
final class SearchFilterUITests: SmartBudUITestCase {

    // MARK: - G14a. Search is applied on top of the type filter

    func testG14_searchRespectsCurrentTypeFilter() throws {
        let app = launch()

        // One expense (餐饮) and one income (工资).
        openEntryForm(in: app)
        enterAmount("12.50", in: app)
        selectCategory("餐饮", in: app)
        saveEntry(in: app)
        waitForRowCount(1, in: app)

        openEntryForm(in: app)
        selectEntryType(income: true, in: app)
        enterAmount("20", in: app)
        selectCategory("工资", in: app)
        saveEntry(in: app)
        waitForRowCount(2, in: app)

        // Filter to expenses first, then search for the income category.
        applyFilter("by type", in: app)
        XCTAssertEqual(rowCount(in: app), 1,
                       "The expense filter did not narrow the ledger to one row.")

        search("工资", in: app)
        XCTAssertEqual(rowCount(in: app), 0,
                       "Search ignored the active expense filter and matched an income row.")

        // Same query with the income filter: now it is the row that matches.
        selectSegment(1, identifier: AccessibilityID.logTypeFilter, in: app)
        XCTAssertEqual(rowCount(in: app), 1,
                       "Searching an income category with the income filter found nothing.")
    }

    // MARK: - G14b. The type filter excludes balance adjustments

    func testG14_typeFilterExcludesBalanceAdjustments() throws {
        let app = launch()

        openEntryForm(in: app)
        enterAmount("10", in: app)
        selectCategory("餐饮", in: app)
        saveEntry(in: app)
        waitForRowCount(1, in: app)

        adjustBalance(of: "现金", to: "30", in: app)

        // Both rows are in the unfiltered ledger...
        select(.log, in: app)
        waitForRowCount(2, in: app)

        // ...and the expense filter keeps only the real expense: an adjustment
        // is neither income nor spend.
        applyFilter("by type", in: app)
        XCTAssertEqual(rowCount(in: app), 1,
                       "The expense filter still lists the balance adjustment.")
    }

    // MARK: - Helpers

    /// Opens the toolbar filter menu and picks an option. The options are menu
    /// items of a Picker, so the identifier usually does not survive; the
    /// option's copy is the fallback (the launch pins English).
    private func applyFilter(_ option: String, in app: XCUIApplication,
                             file: StaticString = #filePath, line: UInt = #line) {
        require(app, AccessibilityID.logFilter, file: file, line: line).tap()
        let identified = element(app, AccessibilityID.logFilterOption(option))
        if identified.waitForExistence(timeout: 5) {
            identified.tap()
            return
        }
        let titled = app.buttons.matching(
            NSPredicate(format: "label CONTAINS %@", option)).firstMatch
        if titled.waitForExistence(timeout: 5) {
            titled.tap()
            return
        }
        XCTFail("Filter option \"\(option)\" is missing.\n\(app.debugDescription)",
                file: file, line: line)
    }

    private func search(_ query: String, in app: XCUIApplication,
                        file: StaticString = #filePath, line: UInt = #line) {
        let field = app.searchFields.firstMatch
        if !field.waitForExistence(timeout: 10) {
            XCTFail("The search field is missing.\n\(app.debugDescription)", file: file, line: line)
            return
        }
        field.tap()
        field.typeText(query)
    }

    private func selectSegment(_ index: Int, identifier: String, in app: XCUIApplication,
                               file: StaticString = #filePath, line: UInt = #line) {
        let control = app.segmentedControls.matching(identifier: identifier).firstMatch
        let target = control.exists ? control : app.segmentedControls.firstMatch
        if !target.waitForExistence(timeout: 10) {
            XCTFail("Segmented control \(identifier) is missing.\n\(app.debugDescription)",
                    file: file, line: line)
            return
        }
        target.buttons.element(boundBy: index).tap()
    }

    /// Account list → long-press the row → Adjust Balance → new value → Done.
    /// The adjustment writes a row that moves the balance without being spend.
    private func adjustBalance(of account: String, to value: String,
                               in app: XCUIApplication,
                               file: StaticString = #filePath, line: UInt = #line) {
        select(.settings, in: app)
        tapSettingRow(AccessibilityID.settingsRow("accounts"), in: app)

        let row = app.buttons.matching(identifier: AccessibilityID.accountsRow)
            .matching(NSPredicate(format: "label CONTAINS %@", account))
            .firstMatch
        if !row.waitForExistence(timeout: 10) {
            XCTFail("No account row \"\(account)\".\n\(app.debugDescription)", file: file, line: line)
            return
        }
        row.press(forDuration: 1.2)

        let adjust = app.buttons.matching(
            NSPredicate(format: "label CONTAINS %@", "Adjust Balance")).firstMatch
        if !adjust.waitForExistence(timeout: 10) {
            XCTFail("The account menu has no Adjust Balance.\n\(app.debugDescription)",
                    file: file, line: line)
            return
        }
        adjust.tap()

        let alert = app.alerts.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 10),
                      "The adjustment alert never appeared.\n\(app.debugDescription)",
                      file: file, line: line)
        let field = alert.textFields.firstMatch
        field.tap()
        let current = (field.value as? String) ?? ""
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count) + value)
        alert.buttons["Done"].firstMatch.tap()
    }
}
