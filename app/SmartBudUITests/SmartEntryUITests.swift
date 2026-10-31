//
//  SmartEntryUITests.swift
//  SmartBudUITests
//
//  Flow K — smart entry: natural-language text → parsed preview → fill the form.
//  The parser itself is covered by unit tests; what these cases pin down is the
//  promise that confirming *fills the form without saving*, and that cancelling
//  leaves nothing behind.
//

import XCTest

final class SmartEntryUITests: SmartBudUITestCase {

    func testK18_smartEntryPreviewAndApply_fillsFormWithoutSaving() throws {
        let app = launch()
        openEntryForm(in: app)
        require(app, AccessibilityID.entrySmartEntry).tap()

        let field = require(app, AccessibilityID.smartEntryField)
        field.tap()
        field.typeText("午饭 35 元")
        require(app, AccessibilityID.smartEntryParse).tap()

        let amount = require(app, AccessibilityID.smartEntryPreviewAmount, timeout: 15)
        XCTAssertTrue(amount.label.contains("35"),
                      "The preview lost the amount: \"\(amount.label)\"")
        let category = require(app, AccessibilityID.smartEntryPreviewCategory)
        XCTAssertTrue(category.label.contains("餐饮"),
                      "The preview lost the category: \"\(category.label)\"")

        require(app, AccessibilityID.smartEntryApply).tap()

        // Form filled...
        XCTAssertEqual(entryAmount(in: app) ?? -1, 35, accuracy: 0.001,
                       "The parsed amount was not written into the form.\n\(app.debugDescription)")
        XCTAssertTrue(element(app, AccessibilityID.entryCategoryButton).label.contains("餐饮"),
                      "The parsed category was not selected in the form.")
        // ...and not saved.
        XCTAssertEqual(rowCount(in: app), 0, "Confirming smart entry saved the transaction.")

        // Closing the filled form asks before discarding, then leaves no row.
        require(app, AccessibilityID.entryCancel).tap()
        app.alerts.firstMatch.buttons["Discard"].firstMatch.tap()
        require(app, AccessibilityID.logAddButton)
        XCTAssertEqual(rowCount(in: app), 0, "The discarded smart entry was written anyway.")
    }

    func testK18_smartEntryCancel_leavesFormEmpty() throws {
        let app = launch()
        openEntryForm(in: app)
        require(app, AccessibilityID.entrySmartEntry).tap()

        let field = require(app, AccessibilityID.smartEntryField)
        field.tap()
        field.typeText("午饭 35 元")
        require(app, AccessibilityID.smartEntryParse).tap()
        require(app, AccessibilityID.smartEntryPreview, timeout: 15)

        // Close the sheet without applying anything.
        require(app, AccessibilityID.smartEntryClose).tap()

        XCTAssertEqual(entryAmount(in: app) ?? -1, 0, accuracy: 0.001,
                       "Cancelling smart entry filled the form.")
        require(app, AccessibilityID.entryCancel).tap()
        require(app, AccessibilityID.logAddButton)
        XCTAssertEqual(rowCount(in: app), 0, "Cancelling smart entry wrote a row.")
    }
}
