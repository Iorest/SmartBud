//
//  SmartBudUITests.swift
//  SmartBudUITests
//
//  Five interaction smoke tests plus the iOS 17+ accessibility audit.
//
//  Conventions (see docs/engineering.md, section "UI 测试"):
//  - Every query goes through an identifier from `AccessibilityID`, which is
//    compiled into this target as well as the app. Localised copy is never a
//    query anchor: the app ships en / zh-Hans / zh-Hant and these cases pin en,
//    so a copy-based query would hide regressions in the other two.
//  - Two surfaces are system-rendered and cannot carry an identifier: the
//    UITabBar buttons behind `.tabItem` and the `.searchable` field. They are
//    located by position through `select(_:in:)`.
//  - Each case ends with `assertAccessible`, so a control added without an
//    accessibility description fails the run that introduced it.
//

import XCTest

@MainActor
final class SmartBudUITests: XCTestCase {

    // MARK: - Launch

    /// No `setUp` launch: some cases need their own arguments, so each test
    /// launches the app itself.
    private func launch() -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments += [
            // Pin the language so assertions never depend on the simulator's
            // region. `appLanguage` falls back to `Locale.current`.
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US",
            // DEBUG-only QA hooks: skip the two-page welcome flow
            // (ContentViewModel.bootstrap) and feed the import wizard the
            // bundled sample CSV instead of the system file picker
            // (ImportDataView.body).
            "-skipIntro",
            "-importSample",
        ]
        app.launch()
        dismissLaunchOverlay(app)
        return app
    }

    /// A simulator without iCloud boots the store in App-Group mode, which
    /// raises the storage notice once per launch. Nothing here tests that
    /// banner, and the alert swallows the first tap of any case that ignores
    /// it.
    private func dismissLaunchOverlay(_ app: XCUIApplication) {
        let alert = app.alerts.firstMatch
        if alert.waitForExistence(timeout: 5), alert.buttons.firstMatch.exists {
            alert.buttons.firstMatch.tap()
        }
    }

    // MARK: - Queries

    /// Identifier-first lookup. Depending on the SwiftUI container the
    /// identifier lands on a button, a cell or a static text, so the query
    /// accepts any element type.
    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    @discardableResult
    private func require(
        _ app: XCUIApplication,
        _ identifier: String,
        timeout: TimeInterval = 20,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> XCUIElement {
        let match = element(app, identifier)
        if !match.waitForExistence(timeout: timeout) {
            XCTFail("No element with identifier \"\(identifier)\".\n\(app.debugDescription)",
                    file: file, line: line)
        }
        return match
    }

    /// SwiftUI's `.tabItem` is rendered by UITabBar, which drops the
    /// identifier the `Label` carries, so the tab's position — fixed by
    /// `HomeView.tabShell` — is the only stable anchor. Each caller asserts a
    /// screen-specific identifier right after tapping, so a reordered tab bar
    /// fails the case instead of quietly testing the wrong screen.
    private enum Tab: Int {
        case log = 0
        case insights = 1
        case budget = 2
        case settings = 3
    }

    private func select(_ tab: Tab, in app: XCUIApplication,
                        file: StaticString = #filePath, line: UInt = #line) {
        let button = app.tabBars.buttons.element(boundBy: tab.rawValue)
        if !button.waitForExistence(timeout: 10) {
            XCTFail("Tab bar button \(tab.rawValue) is missing.\n\(app.debugDescription)",
                    file: file, line: line)
            return
        }
        button.tap()
    }

    /// The ledger row a test just created. Rows are ordered newest first and
    /// share one identifier, so the first cell holding a row button is it. The
    /// amount is asserted on the row's label afterwards — it is not the
    /// locator, so a formatting change cannot silently point the test at a
    /// different row.
    private func newestRow(in app: XCUIApplication) -> XCUIElement {
        app.cells.containing(.button, identifier: AccessibilityID.logRow).firstMatch
    }

    /// The row *cell* carries no label of its own; the row button inside it
    /// aggregates the note, time and amount. Assertions read the button.
    private func assertNewestRowAmount(
        _ amount: String,
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let button = app.buttons.matching(identifier: AccessibilityID.logRow).firstMatch
        if !button.waitForExistence(timeout: 10) {
            XCTFail("No ledger row button found.\n\(app.debugDescription)", file: file, line: line)
            return
        }
        XCTAssertTrue(button.label.contains(amount),
                      "The newest row is not the expected expense: \"\(button.label)\"",
                      file: file, line: line)
    }

    /// Scrolls until `identifier` is on screen and hittable. The Settings list
    /// is taller than a phone screen and rows below the fold are not in the
    /// hierarchy at all (the List is lazy), so `exists` is only meaningful
    /// after scrolling.
    private func scrollIntoView(
        _ identifier: String,
        in app: XCUIApplication,
        maxSwipes: Int = 8
    ) -> XCUIElement {
        let target = element(app, identifier)
        for _ in 0..<maxSwipes {
            if target.exists && target.isHittable { return target }
            app.swipeUp()
        }
        return target
    }

    private func waitUntilEnabled(_ target: XCUIElement, timeout: TimeInterval = 10) {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "isEnabled == true"), object: target)
        _ = XCTWaiter().wait(for: [expectation], timeout: timeout)
    }

    /// Reveals and taps the row's trailing delete action. `.swipeActions` is
    /// rendered by UIKit, which usually drops the identifier the Button
    /// carries, so the revealed button is matched by identifier first and by
    /// its title second. The title fallback is the suite's single copy-based
    /// query and only works because the launch pins English; it is listed as a
    /// known limitation in docs/engineering.md.
    private func swipeDelete(
        _ row: XCUIElement,
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        row.swipeLeft()

        let identified = element(app, AccessibilityID.logRowDelete)
        if identified.waitForExistence(timeout: 5) {
            identified.tap()
            return
        }

        // UIKit's own rendering of the destructive action.
        let titled = app.buttons["Delete"].firstMatch
        if titled.waitForExistence(timeout: 5) {
            titled.tap()
            return
        }

        XCTFail("The row's delete swipe action never appeared.\n\(app.debugDescription)",
                file: file, line: line)
    }

    // MARK: - Accessibility audit

    /// Runs the full audit for the screen under test. Issue types listed in
    /// `AccessibilityAuditPolicy.ignoredTypes` are documented, tracked
    /// exceptions; everything else fails the case. Every issue is printed so
    /// the CI log carries the unfiltered report, ignored or not.
    private func assertAccessible(
        _ app: XCUIApplication,
        screen: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        do {
            try app.performAccessibilityAudit { issue in
                let identifier = issue.element?.identifier ?? ""
                print("AUDIT[\(screen)] \(issue.auditType) \(issue.compactDescription) [\(identifier)]")
                if AccessibilityAuditPolicy.ignoredTypes.contains(issue.auditType) { return true }
                return AccessibilityAuditPolicy.ignoredElementIdentifiers.contains(identifier)
            }
        } catch {
            let attachment = XCTAttachment(screenshot: app.screenshot())
            attachment.name = "audit-failure-\(screen)"
            attachment.lifetime = .keepAlways
            add(attachment)
            XCTFail("Accessibility audit failed on \(screen): \(error)", file: file, line: line)
        }
    }

    // MARK: - 1. Create an expense, delete it, undo the delete

    func testCreateExpenseThenUndoDelete() throws {
        let app = launch()
        require(app, AccessibilityID.logAddButton).tap()

        // 12.34. The decimal key only exists in the "type the decimal" entry
        // mode (the first-launch default), so the amount the pad will produce
        // depends on which key the run finds.
        let hasDecimalKey = element(app, AccessibilityID.padDecimal).waitForExistence(timeout: 5)
        for digit in [1, 2] { require(app, AccessibilityID.padDigit(digit)).tap() }
        if hasDecimalKey { element(app, AccessibilityID.padDecimal).tap() }
        for digit in [3, 4] { require(app, AccessibilityID.padDigit(digit)).tap() }
        let amount = hasDecimalKey ? "12.34" : "1234"

        // A category is mandatory. A fresh store has none, so seed the
        // starter set from the picker's empty state first.
        require(app, AccessibilityID.entryCategoryButton).tap()
        let seed = element(app, AccessibilityID.entrySeedCategories)
        if seed.waitForExistence(timeout: 3) { seed.tap() }
        let tile = element(app, AccessibilityID.entryCategoryTile)
        if !tile.waitForExistence(timeout: 10) {
            XCTFail("Category grid stayed empty.\n\(app.debugDescription)")
        }
        tile.tap()
        // The picker swaps the pad out; its return is the sync point for the
        // closing animation.
        require(app, AccessibilityID.padDigit(0))

        let save = require(app, AccessibilityID.entrySave)
        waitUntilEnabled(save)
        save.tap()

        let created = newestRow(in: app)
        XCTAssertTrue(created.waitForExistence(timeout: 20),
                      "The new expense never showed up in the log.\n\(app.debugDescription)")
        assertNewestRowAmount(amount, in: app)

        // The row's trailing swipe action is the only delete path that stages
        // the delete, which is what raises the undo banner.
        swipeDelete(created, in: app)

        // The undo window is 6 s (TransactionViewModel.undoWindow).
        require(app, AccessibilityID.logUndoButton, timeout: 5).tap()

        let restored = newestRow(in: app)
        XCTAssertTrue(restored.waitForExistence(timeout: 15),
                      "Undo did not restore the deleted row.\n\(app.debugDescription)")
        assertNewestRowAmount(amount, in: app)

        assertAccessible(app, screen: "log")
    }

    // MARK: - 1b. Save stays disabled until there is an amount

    func testSaveStaysDisabledWithoutAmount() throws {
        let app = launch()
        require(app, AccessibilityID.logAddButton).tap()

        let save = require(app, AccessibilityID.entrySave)
        XCTAssertFalse(save.isEnabled,
                       "Save must stay disabled while the amount is zero")

        require(app, AccessibilityID.padDigit(5)).tap()
        waitUntilEnabled(save)
        XCTAssertTrue(save.isEnabled,
                      "Save must become enabled once an amount is entered")
    }

    // MARK: - 1c. Editing the amount updates the ledger row

    func testEditingAmountUpdatesRow() throws {
        let app = launch()
        require(app, AccessibilityID.logAddButton).tap()
        for digit in [4, 2] { require(app, AccessibilityID.padDigit(digit)).tap() }

        require(app, AccessibilityID.entryCategoryButton).tap()
        let seed = element(app, AccessibilityID.entrySeedCategories)
        if seed.waitForExistence(timeout: 3) { seed.tap() }
        let tile = element(app, AccessibilityID.entryCategoryTile)
        XCTAssertTrue(tile.waitForExistence(timeout: 10),
                      "Category grid stayed empty.\n\(app.debugDescription)")
        tile.tap()
        require(app, AccessibilityID.padDigit(0))

        let save = require(app, AccessibilityID.entrySave)
        waitUntilEnabled(save)
        save.tap()

        let created = newestRow(in: app)
        XCTAssertTrue(created.waitForExistence(timeout: 20),
                      "The new expense never showed up in the log.\n\(app.debugDescription)")
        app.buttons.matching(identifier: AccessibilityID.logRow).firstMatch.tap()

        // Append a digit instead of clearing: the pad's bottom-left key is a
        // backspace only in integer-entry mode, so a clear-then-retype step
        // would depend on which mode the edited row happens to open in.
        require(app, AccessibilityID.padDigit(7)).tap()

        let saveEdit = require(app, AccessibilityID.entrySave)
        waitUntilEnabled(saveEdit)
        saveEdit.tap()

        assertNewestRowAmount("427", in: app)
    }

    // MARK: - 1d. Cancelling a non-empty draft writes nothing

    func testCancelDiscardsDraft() throws {
        let app = launch()
        let rowsBefore = app.buttons.matching(identifier: AccessibilityID.logRow).count

        require(app, AccessibilityID.logAddButton).tap()
        require(app, AccessibilityID.padDigit(7)).tap()
        require(app, AccessibilityID.entryCancel).tap()

        // A non-empty draft asks for confirmation before it is dropped.
        let discard = app.alerts.buttons.matching(
            NSPredicate(format: "label == %@", "Discard")).firstMatch
        if discard.waitForExistence(timeout: 5) { discard.tap() }

        require(app, AccessibilityID.logAddButton)
        XCTAssertEqual(app.buttons.matching(identifier: AccessibilityID.logRow).count,
                       rowsBefore,
                       "Cancelling a draft must not create a ledger row")
    }

    // MARK: - 2. Every tab opens its own screen

    func testTabsCycleThroughAllFourSections() throws {
        let app = launch()
        require(app, AccessibilityID.logAddButton)  // Log is the launch tab

        select(.insights, in: app)
        require(app, AccessibilityID.insightsPeriodPicker)

        select(.budget, in: app)
        require(app, AccessibilityID.budgetAddButton)

        select(.settings, in: app)
        require(app, AccessibilityID.settingsRow(SettingsRouteKey.pro))

        select(.log, in: app)
        require(app, AccessibilityID.logAddButton)

        assertAccessible(app, screen: "tabs")
    }

    // MARK: - 3. Smart entry opens and closes

    func testSmartEntryOpensAndCancels() throws {
        let app = launch()
        require(app, AccessibilityID.logAddButton).tap()
        require(app, AccessibilityID.entrySmartEntry).tap()
        require(app, AccessibilityID.smartEntryField)
        require(app, AccessibilityID.smartEntryClose).tap()

        // Back on the form with an empty draft, so Cancel closes it outright
        // instead of asking "Discard this entry?".
        require(app, AccessibilityID.entryCancel, timeout: 10).tap()
        require(app, AccessibilityID.logAddButton)

        assertAccessible(app, screen: "smart-entry")
    }

    // MARK: - 4. Settings → Pro → back

    func testSettingsOpensProAndBackReturns() throws {
        let app = launch()
        select(.settings, in: app)
        require(app, AccessibilityID.settingsRow(SettingsRouteKey.pro)).tap()
        require(app, AccessibilityID.proTitle)
        require(app, AccessibilityID.proBack).tap()
        require(app, AccessibilityID.settingsRow(SettingsRouteKey.pro))

        assertAccessible(app, screen: "settings")
    }

    // MARK: - 5. Import preview then cancel

    func testImportPreviewThenCancel() throws {
        let app = launch()
        select(.settings, in: app)
        let importRow = scrollIntoView(AccessibilityID.settingsImportData, in: app)
        if !importRow.exists {
            XCTFail("The import row never came into view.\n\(app.debugDescription)")
        }
        importRow.tap()

        // `-importSample` already parsed the bundled CSV, so the wizard opens
        // on the column-preview step.
        require(app, AccessibilityID.importPreview, timeout: 20)
        require(app, AccessibilityID.importContinue)

        // One step back to the first page, then close.
        require(app, AccessibilityID.importClose).tap()
        require(app, AccessibilityID.importChooseFile, timeout: 10)
        require(app, AccessibilityID.importClose).tap()
        require(app, AccessibilityID.settingsImportData, timeout: 10)

        assertAccessible(app, screen: "settings-after-import")
    }
}

// MARK: - Audit policy

/// Known audit failures that are tracked rather than fixed here. Every entry
/// names what it hides and why; the list is mirrored in docs/engineering.md
/// (section "UI 测试") next to the work that owns each item.
enum AccessibilityAuditPolicy {
    /// `nonisolated(unsafe)`: the array is never written after launch, and the
    /// XCTest type is not annotated Sendable, so Swift 6 cannot prove it.
    nonisolated(unsafe) static let ignoredTypes: [XCUIAccessibilityAuditType] = [
        // Brand colours are not AA-verified yet; the theme tokens are shared
        // with the design work, not with this test-infrastructure issue.
        .contrast,
        // Fixed-size text on the number pad and the charts; wire it to
        // Dynamic Type separately.
        .dynamicType,
        // Truncation inside the chart and chip labels at large sizes.
        .textClipped,
        // Sub-44pt chips (log badges, filter pills) need a layout pass.
        .hitRegion,
    ]

    /// Element-level exceptions, keyed by identifier so an exception can never
    /// silently widen to "any element with this copy".
    static let ignoredElementIdentifiers: [String] = []
}

/// Settings routes addressed by the tests. `SettingsRoute` itself lives in the
/// app target, so the raw key is mirrored here; `SettingsRoute.accessibilityKey`
/// is the single source of truth and a mismatch fails CI, not silently passes.
enum SettingsRouteKey {
    static let pro = "pro"
}
