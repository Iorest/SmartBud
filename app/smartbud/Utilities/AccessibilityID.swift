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
    /// The two summary cards. Their label carries the formatted total
    /// ("Expenses, $12.50"), which is what the E2E cases read back.
    static let insightsIncomeCard = "sb.insights.incomeCard"
    static let insightsExpenseCard = "sb.insights.expenseCard"
    static let budgetAddButton = "sb.budget.addButton"
    /// "Continue" on the new-budget sheet's first page.
    static let budgetContinue = "sb.budget.continueButton"
    static let budgetTypePicker = "sb.budget.typePicker"
    static let budgetCategoryPicker = "sb.budget.categoryPicker"
    /// One budget tile's remaining figure. Keyed by the budget's name (= the
    /// category name) because more than one budget can be on screen.
    static func budgetRemaining(_ name: String) -> String { "sb.budget.remaining.\(name)" }

    // MARK: - Log

    static let logAddButton = "sb.log.addButton"
    /// Every ledger row shares this identifier (the row's own content is the
    /// ledger data, not a stable anchor); rows are newest first, so a test
    /// that just saved an entry drives the first one.
    static let logRow = "sb.log.row"
    static let logUndoButton = "sb.log.undoButton"
    /// Swipe action on a ledger row; stages the delete so "Undo" can restore it.
    static let logRowDelete = "sb.log.row.delete"
    /// Section header above future/repeating rows.
    static let logUpcomingHeader = "sb.log.upcomingHeader"

    // MARK: - Entry form

    static let entryCancel = "sb.entry.cancel"
    static let entrySave = "sb.entry.save"
    static let entrySmartEntry = "sb.entry.smartEntry"
    static let entryCategoryButton = "sb.entry.categoryButton"
    /// Every tile in the category grid shares this identifier; tests address
    /// them by position, or by the category name the tile's label carries.
    static let entryCategoryTile = "sb.entry.categoryTile"
    static let entrySeedCategories = "sb.entry.seedCategories"
    /// Big amount read-out above the keypad (value = plain amount string).
    static let entryAmountDisplay = "sb.entry.amountDisplay"
    /// The note pill. The E2E cases put a unique note on every entry so they
    /// can find that row again without relying on list order.
    static let entryNoteField = "sb.entry.noteField"
    /// Inline validation toast (entry form and category editors); its label is
    /// the message.
    static let entryToast = "sb.entry.toast"
    /// Optional extras row.
    static let entryAccountChip = "sb.entry.accountChip"
    static let entryDiscountChip = "sb.entry.discountChip"
    static let entryClaimChip = "sb.entry.claimChip"
    static let entryDateButton = "sb.entry.dateButton"
    /// Long-press alternative on the checkmark.
    static let entrySaveAndContinue = "sb.entry.saveAndContinue"
    /// The read-out's trailing delete, the only erase key in "cent-less" entry
    /// mode (the pad's bottom-left key is the decimal point there).
    static let entryAmountDelete = "sb.entry.amountDelete"

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

    // MARK: - Accounts

    static let accountsAddButton = "sb.accounts.addButton"
    static let accountsTransferButton = "sb.accounts.transferButton"
    /// One account's balance figure, keyed by the account name so two rows on
    /// screen are distinguishable.
    static func accountBalance(_ name: String) -> String { "sb.accounts.balance.\(name)" }
    /// One row of the entry form's account picker sheet.
    static func accountOption(_ name: String) -> String { "sb.entry.accountOption.\(name)" }
    static let accountNameField = "sb.accounts.nameField"
    static let accountCurrencyPicker = "sb.accounts.currencyPicker"
    static let accountOpeningBalance = "sb.accounts.openingBalance"
    static let accountDone = "sb.accounts.done"

    // MARK: - Transfer editor

    static let transferFrom = "sb.transfer.from"
    static let transferTo = "sb.transfer.to"
    static let transferAmount = "sb.transfer.amount"
    static let transferFee = "sb.transfer.fee"
    static let transferReceived = "sb.transfer.received"
    static let transferDone = "sb.transfer.done"
}
