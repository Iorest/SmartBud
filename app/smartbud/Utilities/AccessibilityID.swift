//
//  AccessibilityID.swift
//  smartbud
//
//  Single source of truth for the accessibility identifiers XCUITest uses to
//  find controls. The file is compiled into both the app and the
//  `SmartBudUITests` target so a rename breaks the build instead of silently
//  breaking a test at runtime.
//
//  Rules:
//  - Identifiers describe the control's role, never its copy. Localised text
//    must not be used as a query anchor: the app ships en / zh-Hans / zh-Hant
//    and the UI tests pin a single language, so copy-based queries hide
//    regressions in the other two.
//  - `sb.<area>.<element>` — lower camel after the area, dot separated.
//  - Only add an identifier for something a test actually drives or asserts;
//    an identifier nobody reads is dead weight.
//

import Foundation

enum AccessibilityID {
    // MARK: - Tab bar

    static let tabLog = "sb.tab.log"
    static let tabInsights = "sb.tab.insights"
    static let tabBudget = "sb.tab.budget"
    static let tabSettings = "sb.tab.settings"

    // MARK: - Insights / Budget (the other two tabs)

    static let insightsPeriodPicker = "sb.insights.periodPicker"
    static let budgetAddButton = "sb.budget.addButton"

    // MARK: - Log

    static let logAddButton = "sb.log.addButton"
    static let logUndoButton = "sb.log.undoButton"
    /// Swipe action on a ledger row; stages the delete so "Undo" can restore it.
    static let logRowDelete = "sb.log.row.delete"

    // MARK: - Entry form

    static let entryCancel = "sb.entry.cancel"
    static let entrySave = "sb.entry.save"
    static let entrySmartEntry = "sb.entry.smartEntry"
    static let entryCategoryButton = "sb.entry.categoryButton"
    /// Every tile in the category grid shares this identifier; tests address
    /// them by position because the tile's own label is the category name.
    static let entryCategoryTile = "sb.entry.categoryTile"
    static let entrySeedCategories = "sb.entry.seedCategories"

    // MARK: - Number pad

    static func padDigit(_ digit: Int) -> String { "sb.pad.digit.\(digit)" }
    static let padDecimal = "sb.pad.decimal"
    static let padBackspace = "sb.pad.backspace"

    // MARK: - Smart entry sheet

    static let smartEntryClose = "sb.smartEntry.close"
    static let smartEntryField = "sb.smartEntry.field"

    // MARK: - Settings

    /// One per `SettingsRoute`, so a new screen gets an identifier for free.
    static func settingsRow(_ route: String) -> String { "sb.settings.row.\(route)" }
    static let settingsImportData = "sb.settings.importData"

    // MARK: - Pro

    static let proBack = "sb.pro.back"
    static let proTitle = "sb.pro.title"
    /// Wraps the StoreKit `ProductView`s. The purchase buttons themselves are
    /// system-rendered and cannot carry an identifier.
    static let proPurchaseSection = "sb.pro.purchaseSection"
    static let proRestore = "sb.pro.restore"

    // MARK: - CSV import wizard

    /// Top-left button: dismisses on step 1, steps back afterwards.
    static let importClose = "sb.import.close"
    static let importChooseFile = "sb.import.chooseFile"
    /// Column-preview table title; only on screen after a CSV was parsed.
    static let importPreview = "sb.import.preview"
    static let importContinue = "sb.import.continueButton"
}
