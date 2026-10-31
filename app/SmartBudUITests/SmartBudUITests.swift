//
//  SmartBudUITests.swift
//  SmartBudUITests
//
//  Five interaction smoke tests plus an accessibility audit per test.
//  See docs/engineering.md ("怎么跑 UI 测试") for the rationale and the
//  currently skipped audit categories.
//

import XCTest

final class SmartBudUITests: XCTestCase {

    private var app: XCUIApplication!

    // MARK: - Lifecycle

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        // The first-run welcome flow covers the whole app; the app skips it
        // for UI tests (DEBUG hook in ContentViewModel.bootstrap).
        app.launchArguments.append("-uiTestSkipIntro")
        // Only the import wizard reads this (DEBUG hook in
        // ImportDataView.onAppear); it keeps that test off the system file
        // picker. Other tests never open the wizard.
        app.launchEnvironment["IMPORT_SAMPLE"] = "1"
        app.launch()
        XCTAssertTrue(
            app.tabBars.firstMatch.waitForExistence(timeout: 60),
            "The tab bar never appeared — the app did not finish launching."
        )
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - 1. Create an expense, save, delete, undo

    func testCreateExpenseSaveAndUndo() throws {
        app.buttons[UITestID.logAdd].tap()
        XCTAssertTrue(
            app.buttons[UITestID.keypadDigit(1)].waitForExistence(timeout: 10),
            "The entry form did not open."
        )

        app.buttons[UITestID.keypadDigit(1)].tap()
        app.buttons[UITestID.keypadDigit(2)].tap()
        app.buttons[UITestID.keypadDigit(3)].tap()
        selectFirstCategory()

        let save = app.buttons[UITestID.entrySave]
        XCTAssertTrue(save.waitForExistence(timeout: 5), "The save button is missing.")
        XCTAssertTrue(save.isEnabled, "The save button stayed disabled with an amount and a category.")
        save.tap()

        let rows = app.buttons.matching(identifier: UITestID.logRow)
        XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: 10), "The saved transaction is not in the log.")
        let countAfterSave = rows.count

        rows.firstMatch.swipeLeft(velocity: .slow)
        let delete = app.buttons[UITestID.logSwipeDelete]
        XCTAssertTrue(delete.waitForExistence(timeout: 5), "The swipe-to-delete action is missing.")
        delete.tap()

        // Swipe delete stages the removal and shows the undo bar; there is no
        // confirmation alert on this path (the undo window is 6 s).
        let undo = app.buttons[UITestID.logUndo]
        XCTAssertTrue(undo.waitForExistence(timeout: 5), "The undo bar did not appear after deleting.")
        XCTAssertEqual(rows.count, countAfterSave - 1, "The row was not removed after swiping to delete.")

        undo.tap()
        XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: 5), "Undo did not restore the deleted row.")
        XCTAssertTrue(waitForCount(rows, countAfterSave), "Undo restored a different number of rows.")

        assertAccessibility(of: "log after undo")
    }

    // MARK: - 2. Every tab can be selected

    func testAllTabsSwitch() throws {
        for (index, identifier) in UITestID.tabs.enumerated() {
            let tab = tabButton(index: index, identifier: identifier)
            XCTAssertTrue(tab.waitForExistence(timeout: 10), "Tab \(identifier) is missing.")
            tab.tap()
            XCTAssertTrue(tab.isSelected, "Tapping \(identifier) did not select it.")
        }

        assertAccessibility(of: "settings tab")
    }

    // MARK: - 3. Smart entry opens and closes without touching the form

    func testSmartEntryCancel() throws {
        app.buttons[UITestID.logAdd].tap()

        let smart = app.buttons[UITestID.entrySmart]
        XCTAssertTrue(smart.waitForExistence(timeout: 10), "The smart entry button is missing.")
        smart.tap()

        let input = app.textFields[UITestID.smartInput]
        XCTAssertTrue(input.waitForExistence(timeout: 10), "The smart entry sheet did not open.")
        assertAccessibility(of: "smart entry sheet")

        app.buttons[UITestID.smartClose].tap()
        XCTAssertTrue(waitForDisappearance(input), "The smart entry sheet did not close.")

        // Nothing was typed, so Cancel closes the form without a discard alert.
        let cancel = app.buttons[UITestID.entryCancel]
        XCTAssertTrue(cancel.waitForExistence(timeout: 5), "The entry form did not survive closing the sheet.")
        cancel.tap()
        XCTAssertTrue(
            waitForDisappearance(app.buttons[UITestID.entrySave]),
            "Cancel did not dismiss the entry form."
        )
    }

    // MARK: - 4. Settings → Pro → back

    func testSettingsProBack() throws {
        tabButton(index: 3, identifier: UITestID.tabs[3]).tap()

        let proRow = app.buttons[UITestID.settingsPro]
        XCTAssertTrue(proRow.waitForExistence(timeout: 10), "The Pro row is missing from Settings.")
        proRow.tap()

        let back = app.buttons[UITestID.proBack]
        XCTAssertTrue(back.waitForExistence(timeout: 10), "The Pro screen did not open.")
        assertAccessibility(of: "pro screen")

        back.tap()
        XCTAssertTrue(
            app.buttons[UITestID.settingsPro].waitForExistence(timeout: 10),
            "Back from Pro did not return to Settings."
        )

        assertAccessibility(of: "settings root")
    }

    // MARK: - 5. Import → mapping preview → cancel

    func testImportPreviewCancel() throws {
        tabButton(index: 3, identifier: UITestID.tabs[3]).tap()

        let importRow = app.buttons[UITestID.settingsImport]
        XCTAssertTrue(importRow.waitForExistence(timeout: 10), "The import row is missing from Settings.")
        scrollUntilHittable(importRow)
        importRow.tap()

        // IMPORT_SAMPLE makes the wizard read the bundled sample CSV instead of
        // the system document picker (DEBUG hook in ImportDataView.onAppear).
        let back = app.buttons[UITestID.importBack]
        XCTAssertTrue(back.waitForExistence(timeout: 10), "The import wizard did not open.")
        XCTAssertFalse(
            app.buttons[UITestID.importPick].exists,
            "The import wizard stayed on step 1; the sample file was not parsed into the preview."
        )
        assertAccessibility(of: "import mapping preview")

        back.tap()
        XCTAssertTrue(
            app.buttons[UITestID.importPick].waitForExistence(timeout: 5),
            "Back did not return to the file-picking step."
        )
        back.tap()
        XCTAssertTrue(
            app.buttons[UITestID.settingsImport].waitForExistence(timeout: 10),
            "Closing the import wizard did not return to Settings."
        )
    }

    // MARK: - Entry helpers

    /// Picks the first expense category, seeding the starter set when the
    /// simulator starts with an empty category list.
    private func selectFirstCategory() {
        let pill = app.buttons[UITestID.entryCategory]
        XCTAssertTrue(pill.waitForExistence(timeout: 5), "The category picker button is missing.")
        pill.tap()

        let firstTile = app.buttons[UITestID.categoryTile(0)]
        if !firstTile.waitForExistence(timeout: 3) {
            let seed = app.buttons[UITestID.entryCategorySeed]
            XCTAssertTrue(seed.waitForExistence(timeout: 5), "The category grid is empty and offers no starter set.")
            seed.tap()
        }
        XCTAssertTrue(firstTile.waitForExistence(timeout: 5), "No category tile to select.")
        firstTile.tap()
    }

    // MARK: - Navigation helpers

    private func tabButton(index: Int, identifier: String) -> XCUIElement {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 20), "The tab bar is missing.")
        let byIdentifier = tabBar.buttons[identifier]
        if byIdentifier.exists {
            return byIdentifier
        }
        // SwiftUI does not always forward a tab item's identifier to the
        // UITabBarButton. The strip order is fixed by HomeView, so fall back to
        // the index rather than anchoring on the localized title.
        return tabBar.buttons.element(boundBy: index)
    }

    private func scrollUntilHittable(_ element: XCUIElement, maxSwipes: Int = 6) {
        var swipes = 0
        while !element.isHittable && swipes < maxSwipes {
            app.swipeUp()
            swipes += 1
        }
    }

    // MARK: - Wait helpers

    private func waitForDisappearance(_ element: XCUIElement, timeout: TimeInterval = 5) -> Bool {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"),
            object: element
        )
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }

    private func waitForCount(
        _ query: XCUIElementQuery,
        _ expected: Int,
        timeout: TimeInterval = 5
    ) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if query.count == expected { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        return query.count == expected
    }

    // MARK: - Accessibility audit

    /// Runs the iOS 17+ accessibility audit and keeps a screenshot when it
    /// fails. See AccessibilityAuditPolicy for the deliberately skipped types.
    private func assertAccessibility(of screen: String, file: StaticString = #filePath, line: UInt = #line) {
        do {
            try app.performAccessibilityAudit(for: AccessibilityAuditPolicy.auditedTypes)
        } catch {
            let screenshot = XCTAttachment(screenshot: app.screenshot())
            screenshot.name = "accessibility-audit-\(screen)"
            screenshot.lifetime = .keepAlways
            add(screenshot)
            XCTFail("Accessibility audit failed on \(screen): \(error)", file: file, line: line)
        }
    }
}
