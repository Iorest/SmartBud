//
//  LayoutUITests.swift
//  SmartBudUITests
//
//  Flow M — the layout matrix: the entry form in landscape, the primary path on
//  a small phone, and the iPad's NavigationSplitView. These cases run on their
//  own destinations (see the `ui-layout` job in `.github/workflows/ci.yml`);
//  each one skips when it finds itself on the wrong device class, so the two
//  destinations can run the same class without lying to each other.
//
//  "Not clipped" means the control is hittable, not merely present: the entry
//  form's number pad has a fixed 72pt row height, and a clipped pad still has
//  its keys in the accessibility tree.
//

import XCTest

@MainActor
final class LayoutUITests: SmartBudUITestCase {

    override func tearDown() {
        XCUIDevice.shared.orientation = .portrait
        super.tearDown()
    }

    // MARK: - M20a. Landscape entry form keeps the primary path usable

    func testM20_entryFormLandscape_primaryPathStillReachable() throws {
        let app = launch()
        try XCTSkipIf(app.tabBars.firstMatch.exists == false,
                      "iPad run: landscape entry is covered by the phone destination.")

        XCUIDevice.shared.orientation = .landscapeLeft
        openEntryForm(in: app)

        // Amount → category → save, the three taps the form exists for.
        enterAmount("12.50", in: app)
        XCTAssertTrue(element(app, AccessibilityID.entryAmount).isHittable,
                      "The amount read-out is not hittable in landscape.\n\(app.debugDescription)")

        selectCategory("餐饮", in: app)
        let save = require(app, AccessibilityID.entrySave)
        waitUntilEnabled(save)
        XCTAssertTrue(save.isHittable,
                      "The save key is clipped off-screen in landscape.\n\(app.debugDescription)")
        save.tap()

        waitForRowCount(1, in: app)
        assertNewestRowAmount("12.50", in: app)
    }

    // MARK: - M20b. Small phone: the primary path fits without scrolling

    func testM20_smallPhone_primaryPathVisibleWithoutScrolling() throws {
        let app = launch()
        let height = app.windows.firstMatch.frame.height
        try XCTSkipIf(height > 700,
                      "Not a small phone (window height \(height)pt); the small-phone destination owns this case.")

        // A1: the floating add button is inside the bottom third of the screen
        // (the ergonomics rule in docs/design.md §9.0).
        let add = require(app, AccessibilityID.logAddButton)
        XCTAssertTrue(add.frame.midY > app.windows.firstMatch.frame.height * 0.55,
                      "The add button is not in the thumb zone: \(add.frame)")

        openEntryForm(in: app)
        enterAmount("12.50", in: app)
        let save = require(app, AccessibilityID.entrySave)
        waitUntilEnabled(save)
        XCTAssertTrue(save.isHittable,
                      "The save key does not fit a small phone.\n\(app.debugDescription)")
        XCTAssertTrue(element(app, AccessibilityID.entryCategoryButton).isHittable,
                      "The category pill does not fit a small phone.")

        selectCategory("餐饮", in: app)
        save.tap()
        waitForRowCount(1, in: app)
        assertNewestRowAmount("12.50", in: app)
    }

    // MARK: - M20c. iPad: sidebar + detail instead of the tab strip

    func testM20_ipadSplitView_navigatesBetweenSections() throws {
        let app = launch()
        try XCTSkipIf(app.tabBars.firstMatch.exists,
                      "Phone run: the split-view layout only exists at regular width.")

        // Every section is reachable from the sidebar, and the detail column
        // swaps with it.
        require(app, AccessibilityID.sidebarTab("log"))
        require(app, AccessibilityID.logAddButton)

        require(app, AccessibilityID.sidebarTab("insights")).tap()
        require(app, AccessibilityID.insightsPeriodPicker)

        require(app, AccessibilityID.sidebarTab("budget")).tap()
        require(app, AccessibilityID.budgetAddButton)

        require(app, AccessibilityID.sidebarTab("settings")).tap()
        require(app, AccessibilityID.settingsRow("pro"))

        // The detail column stays a readable width (docs/design.md §9: 860pt).
        let detail = app.buttons.matching(identifier: AccessibilityID.settingsRow("pro")).firstMatch
        XCTAssertLessThanOrEqual(detail.frame.maxX, 1100,
                                 "The detail column is not width-constrained: \(detail.frame)")
    }
}
