//
//  DeepLinkLockUITests.swift
//  SmartBudUITests
//
//  Flows H (deep link) and I (App Lock).
//
//  The URL arrives through `DEEPLINK_URL` rather than `XCUIApplication.open`,
//  because opening a URL from a test raises the system's "Open in SmartBud?"
//  prompt, and dismissing that prompt also sends the app through
//  `.inactive` — which re-locks an App-Locked session and makes the locked
//  case untestable. `HomeView` feeds the value to the same two handlers the
//  `.onOpenURL` chain uses, so routing, category matching and the locked
//  refusal are the production code paths.
//
//  App Lock cannot be turned on from the UI in CI: the toggle authenticates
//  with a device passcode first, and a simulator has none. `-uiTestLock` writes
//  the same key the toggle writes; `-uiTestUnlock` makes the single unlock
//  attempt succeed without the system sheet. Both are DEBUG-only.
//

import XCTest

@MainActor
final class DeepLinkLockUITests: SmartBudUITestCase {

    private static let addFoodURL =
        "smartbud://add?amount=35&category=%E9%A4%90%E9%A5%AE"   // 餐饮

    // MARK: - H15. The add route writes the entry it was asked for

    func testH15_deepLinkAdd_createsRowWithAmountAndCategory() throws {
        let app = launch(environment: ["DEEPLINK_URL": Self.addFoodURL])

        waitForRowCount(1, in: app)
        let row = app.buttons.matching(identifier: AccessibilityID.logRow).firstMatch
        XCTAssertTrue(row.label.contains("35"),
                      "The deep-linked amount is not on the row: \"\(row.label)\"")
        XCTAssertTrue(row.label.contains("餐饮"),
                      "The deep-linked category is not on the row: \"\(row.label)\"")

        select(.insights, in: app)
        assertAmount(require(app, AccessibilityID.insightsExpenseCard),
                     equals: 35, "Insights expenses after a deep link")
    }

    func testH15_deepLinkWithoutAmount_writesNothing() throws {
        // `amount` is mandatory; the router answers `invalid_amount` and must
        // not fall back to a zero row.
        let app = launch(environment: ["DEEPLINK_URL": "smartbud://add?category=%E9%A4%90%E9%A5%AE"])
        XCTAssertEqual(rowCount(in: app), 0,
                       "A deep link without an amount still wrote a row.")
    }

    // MARK: - H15b. While locked, the add route is refused

    func testH15_deepLinkWhileLocked_refusesToWrite() throws {
        let app = launch(["-uiTestLock", "-uiTestUnlock"],
                         environment: ["DEEPLINK_URL": Self.addFoodURL])

        require(app, AccessibilityID.lockScreen)
        XCTAssertEqual(rowCount(in: app), 0, "A locked app accepted a deep-link write.")

        // Unlock, then confirm the ledger really is empty: the refusal must be
        // a refusal, not a row hidden behind the lock screen.
        require(app, AccessibilityID.lockUnlockButton).tap()
        requireDisappearance(app, AccessibilityID.lockScreen, timeout: 10)
        require(app, AccessibilityID.logAddButton)
        XCTAssertEqual(rowCount(in: app), 0, "The refused deep link was written after unlocking.")
    }

    // MARK: - I16. A locked app asks for the unlock before showing anything

    func testI16_lockAtLaunch_requiresUnlock() throws {
        let app = launch(["-uiTestLock", "-uiTestUnlock"])

        require(app, AccessibilityID.lockScreen)
        require(app, AccessibilityID.lockUnlockButton)

        require(app, AccessibilityID.lockUnlockButton).tap()
        requireDisappearance(app, AccessibilityID.lockScreen, timeout: 10)
        require(app, AccessibilityID.logAddButton)
    }

    func testI16_lockRelocksWhenTheAppGoesToTheBackground() throws {
        let app = launch(["-uiTestLock", "-uiTestUnlock"])
        require(app, AccessibilityID.lockUnlockButton).tap()
        requireDisappearance(app, AccessibilityID.lockScreen, timeout: 10)

        cycleToBackground(in: app)

        // Back in the foreground the ledger must be behind the lock again —
        // this is the "switch apps and come back" path users actually hit.
        let lock = require(app, AccessibilityID.lockScreen, timeout: 15)
        XCTAssertTrue(lock.exists, "The app did not re-lock after backgrounding.")
    }

    // MARK: - I16b. A new-entry request that arrives locked is replayed after unlock

    func testI16_newEntryQueuedWhileLocked_replaysAfterUnlock() throws {
        let app = launch(["-uiTestLock", "-uiTestUnlock"],
                         environment: ["DEEPLINK_URL": "smartbud://newexpense"])

        require(app, AccessibilityID.lockScreen)
        requireAbsence(app, AccessibilityID.entrySave, timeout: 3)

        require(app, AccessibilityID.lockUnlockButton).tap()

        // The queued request opens the form — not a row, the form.
        require(app, AccessibilityID.entrySave, timeout: 15)
        XCTAssertEqual(rowCount(in: app), 0,
                       "The replayed new-entry request wrote a row by itself.")
    }
}
