//
//  SettingsUITests.swift
//  SmartBudUITests
//
//  Flow L — the three settings whose effect a user can see: language, dark
//  mode, base currency. Each case asserts the *result* (button copy, screen
//  brightness, the conversion warning), never the picker's selection alone.
//
//  Language is applied on the next launch, so that case relaunches the app
//  with `-uiTestKeepDefaults` (otherwise the fixture would wipe the language it
//  just stored). Dark mode has no XCUITest API, so it compares the average
//  brightness of the same screen before and after.
//

import XCTest

final class SettingsUITests: SmartBudUITestCase {

    // MARK: - L19a. Switching the language changes the UI copy

    func testL19_languageSwitch_changesButtonCopy() throws {
        let app = launch()
        let before = require(app, AccessibilityID.logAddButton).label
        XCTAssertFalse(before.isEmpty, "The add button carries no description to compare.")

        select(.settings, in: app)
        tapSettingRow(AccessibilityID.settingsRow("language"), in: app)
        require(app, AccessibilityID.settingsLanguageRow("zh-Hans")).tap()

        // The app applies a language on the next launch (it says so on screen).
        app.terminate()
        let relaunched = launch(["-uiTestKeepDefaults"], seed: false)

        let after = require(relaunched, AccessibilityID.logAddButton).label
        XCTAssertNotEqual(after, before,
                          "The UI copy did not change after switching to zh-Hans (still \"\(after)\").")
    }

    // MARK: - L19b. Dark mode actually darkens the screen

    func testL19_darkMode_darkensTheScreen() throws {
        let app = launch()
        select(.settings, in: app)
        require(app, AccessibilityID.settingsRow("appearance"))

        let light = averageBrightness(of: app.screenshot())
        XCTAssertGreaterThan(light, 0, "Could not read the light-mode screenshot.")

        tapSettingRow(AccessibilityID.settingsRow("appearance"), in: app)
        let darkOption = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@", "Dark")).firstMatch
        if darkOption.waitForExistence(timeout: 10) {
            darkOption.tap()
        } else {
            // Inline pickers are UIKit-rendered; segment 2 is Dark.
            let picker = require(app, AccessibilityID.settingsAppearancePicker)
            picker.buttons.element(boundBy: 2).tap()
        }

        // The appearance screen dismisses itself once the choice changes.
        let backOnSettings = require(app, AccessibilityID.settingsRow("appearance"), timeout: 15)
        XCTAssertTrue(backOnSettings.exists)

        let dark = averageBrightness(of: app.screenshot())
        XCTAssertLessThan(dark, light - 0.15,
                          "Dark mode did not darken the screen (light \(light), dark \(dark)).")
    }

    // MARK: - L19c. Switching the base currency warns that history is re-based

    func testL19_baseCurrencySwitch_showsConversionHint() throws {
        let app = launch()
        select(.settings, in: app)
        tapSettingRow(AccessibilityID.settingsRow("currency"), in: app)

        // The seeded CNY rate forces a conversion, which is what raises the
        // warning. The list is long, so the search field narrows it first.
        var cny = element(app, AccessibilityID.settingsCurrencyRow("CNY"))
        if !cny.waitForExistence(timeout: 5) {
            let search = app.searchFields.firstMatch
            if search.waitForExistence(timeout: 5) {
                search.tap()
                search.typeText("CNY")
            }
            cny = element(app, AccessibilityID.settingsCurrencyRow("CNY"))
        }
        XCTAssertTrue(cny.waitForExistence(timeout: 10),
                      "The CNY row is missing.\n\(app.debugDescription)")
        cny.tap()

        let alert = app.alerts.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 10),
                      "Switching the base currency with data did not ask.\n\(app.debugDescription)")
        let message = alert.staticTexts.allElementsBoundByIndex.map(\.label).joined(separator: " ")
        XCTAssertTrue(message.lowercased().contains("converted"),
                      "The confirmation does not explain that stored amounts are converted: \"\(message)\"")
        XCTAssertTrue(message.contains("records"),
                      "The confirmation does not say how many records are affected: \"\(message)\"")

        alert.buttons["Switch"].firstMatch.tap()

        // The switch happened: the row now reports itself selected.
        let switched = element(app, AccessibilityID.settingsCurrencyRow("CNY"))
        XCTAssertTrue(switched.waitForExistence(timeout: 15))
        XCTAssertTrue(switched.isSelected, "The base currency did not change to CNY.")
    }
}
