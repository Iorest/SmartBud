//
//  UITestIdentifiers.swift
//  SmartBudUITests
//
//  Single source of truth for the accessibility identifiers the UI tests rely
//  on. The app sets these ids in `app/smartbud`; a typo on either side makes a
//  test fail with a missing-element message instead of silently clicking by
//  localized copy.
//

import Foundation

enum UITestID {
    // Tabs, in the same order as `HomeView.tabShell`.
    static let tabs = ["tab.log", "tab.insights", "tab.budget", "tab.settings"]

    // Log
    static let logAdd = "log.add"
    static let logRow = "log.row"
    static let logSwipeDelete = "log.swipe.delete"
    static let logUndo = "log.undo"

    // Transaction entry
    static let entrySave = "entry.save"
    static let entryCancel = "entry.cancel"
    static let entrySmart = "entry.smart"
    static let entryCategory = "entry.category"
    static let entryCategorySeed = "entry.category.seed"
    static let entryCategoryTile = "entry.category.tile"
    static let keypadDecimal = "keypad.decimal"

    static func keypadDigit(_ digit: Int) -> String { "keypad.digit.\(digit)" }
    static func categoryTile(_ index: Int) -> String { "\(entryCategoryTile).\(index)" }

    // Smart entry sheet
    static let smartInput = "smart.input"
    static let smartClose = "smart.close"

    // Settings and Pro
    static let settingsPro = "settings.row.pro"
    static let settingsImport = "settings.import"
    static let proBack = "pro.back"

    // Import wizard
    static let importBack = "import.back"
    static let importPick = "import.pick"
}
