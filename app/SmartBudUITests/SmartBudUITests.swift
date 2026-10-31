//
//  SmartBudUITests.swift
//  SmartBudUITests
//
//  The five smoke cases TELE-24 introduced. They stay as the canary layer: each
//  one is a single short path through a screen, cheap enough to run on every
//  PR. The flow matrix lives next to them (one file per area: entry, editing,
//  transfers/accounts, budget, import/export, deep link/lock, pro/smart entry/
//  settings, layout) and shares the helpers in `UITestSupport.swift`.
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
final class SmartBudUITests: SmartBudUITestCase {

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
