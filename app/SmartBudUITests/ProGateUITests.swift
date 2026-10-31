//
//  ProGateUITests.swift
//  SmartBudUITests
//
//  Flow J — the three Pro gates. `-proEnforced` closes the launch promotion
//  (DEBUG-only hook in `SubscriptionManager`), so all three features are
//  locked. Every case asserts the Pro screen *and* that the gated action did
//  not happen: an upsell that still performs the write is the regression that
//  costs money in reviews, not a cosmetic bug.
//

import XCTest

@MainActor
final class ProGateUITests: SmartBudUITestCase {

    // MARK: - J17a. AI analysis

    func testJ17_aiAnalysisGate_opensProAndWritesNothing() throws {
        let app = launch(["-proEnforced"])

        // A row exists so "nothing was written" is not trivially true.
        openEntryForm(in: app)
        enterAmount("10", in: app)
        selectCategory("餐饮", in: app)
        saveEntry(in: app)
        waitForRowCount(1, in: app)

        select(.insights, in: app)
        require(app, AccessibilityID.insightsAIAnalysis).tap()

        require(app, AccessibilityID.proTitle)
        requireAbsence(app, AccessibilityID.aiScreen, timeout: 3)
        require(app, AccessibilityID.proBack).tap()

        select(.log, in: app)
        waitForRowCount(1, in: app)
    }

    // MARK: - J17b. Extra app icons

    func testJ17_appIconGate_opensProAndKeepsTheCurrentIcon() throws {
        let app = launch(["-proEnforced"])

        select(.settings, in: app)
        tapSettingRow(AccessibilityID.settingsRow("appIcon"), in: app)

        let rows = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "sb.settings.appIcon.row."))
        XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: 15),
                      "No app-icon rows.\n\(app.debugDescription)")
        guard rows.count > 1 else {
            XCTFail("Only one app icon is listed, so there is nothing to gate.")
            return
        }
        rows.element(boundBy: 1).tap()

        require(app, AccessibilityID.proTitle)
        require(app, AccessibilityID.proBack).tap()

        // Back on the icon list with the default still selected: the gate must
        // not have swapped anything.
        let defaultRow = rows.element(boundBy: 0)
        XCTAssertTrue(defaultRow.waitForExistence(timeout: 10))
        XCTAssertTrue(defaultRow.isSelected,
                      "The gated tap changed the active app icon.\n\(app.debugDescription)")
    }

    // MARK: - J17c. Custom daily reminder time

    func testJ17_customReminderGate_opensProAndKeepsTheSchedule() throws {
        let app = launch(["-proEnforced"])

        select(.settings, in: app)
        tapSettingRow(AccessibilityID.settingsRow("notifications"), in: app)

        // The option rows only exist once reminders are on.
        let enable = require(app, AccessibilityID.settingsNotificationEnable)
        if enable.value as? String != "1" {
            enable.tap()
            allowSystemAlertIfPresent()
        }

        let custom = app.buttons.matching(
            NSPredicate(format: "label CONTAINS %@", "Custom")).firstMatch
        if !custom.waitForExistence(timeout: 10) {
            XCTFail("No custom reminder row.\n\(app.debugDescription)")
            return
        }
        custom.tap()

        require(app, AccessibilityID.proTitle)
        require(app, AccessibilityID.proBack).tap()

        // The gate must not have left the schedule on the custom slot.
        requireAbsence(app, AccessibilityID.settingsNotificationCustomTime, timeout: 3)
    }
}
