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

    /// Period net total (the big signed number), average, and the two summary
    /// cards. The cards already carry a combined label ("Expenses, $12.50"),
    /// so a case asserts the amount on the element, never on the copy.
    static let insightsNetTotal = "sb.insights.netTotal"
    static let insightsAverage = "sb.insights.average"
    static let insightsIncomeCard = "sb.insights.incomeCard"
    static let insightsExpenseCard = "sb.insights.expenseCard"
    /// Toolbar entry to the gated AI analysis screen.
    static let insightsAIAnalysis = "sb.insights.aiAnalysis"

    // MARK: - Budget

    /// The list card / row for one budget; its trailing amount is the
    /// remaining figure the cases assert on.
    static let budgetRow = "sb.budget.row"
    static let budgetRowRemaining = "sb.budget.row.remaining"
    static let budgetDetailRemaining = "sb.budget.detail.remaining"
    static let budgetCreateTypePicker = "sb.budget.create.typePicker"
    static let budgetCreateCategoryPicker = "sb.budget.create.categoryPicker"
    static let budgetCreateContinue = "sb.budget.create.continueButton"

    // MARK: - Log

    static let logAddButton = "sb.log.addButton"
    /// Every ledger row shares this identifier (the row's own content is the
    /// ledger data, not a stable anchor); rows are newest first, so a test
    /// that just saved an entry drives the first one.
    static let logRow = "sb.log.row"
    static let logUndoButton = "sb.log.undoButton"
    /// Swipe action on a ledger row; stages the delete so "Undo" can restore it.
    static let logRowDelete = "sb.log.row.delete"
    /// Edit, revealed by the row's leading swipe (same UIKit caveat as delete).
    static let logRowEdit = "sb.log.row.edit"
    /// The toolbar filter menu.
    static let logFilter = "sb.log.filter"
    /// One per `FilterType`, so a case can pick a filter without its copy.
    static func logFilterOption(_ filter: String) -> String { "sb.log.filterOption.\(filter)" }
    /// "UPCOMING" section header — the future-dated partition.
    static let logUpcomingHeader = "sb.log.upcomingHeader"
    /// The summary card at the top of the unfiltered ledger (net total).
    static let logSummary = "sb.log.summary"
    /// Expense / Income segmented control inside the type filter.
    static let logTypeFilter = "sb.log.typeFilter"

    // MARK: - Entry form

    static let entryCancel = "sb.entry.cancel"
    static let entrySave = "sb.entry.save"
    static let entrySmartEntry = "sb.entry.smartEntry"
    static let entryCategoryButton = "sb.entry.categoryButton"
    /// Every tile in the category grid shares this identifier; tests address
    /// them by position because the tile's own label is the category name.
    static let entryCategoryTile = "sb.entry.categoryTile"
    static let entrySeedCategories = "sb.entry.seedCategories"

    /// The big amount read-out above the pad. It is the only place the typed
    /// value is visible, so a test asserting "the digit did not fit any more"
    /// reads this element instead of guessing at a formatted string.
    static let entryAmount = "sb.entry.amount"
    /// Expense / Income segmented control. UIKit renders the segments, so the
    /// control carries the identifier and the segments are addressed by
    /// position (see `SBUITestCase.selectEntryType`).
    static let entryTypePicker = "sb.entry.typePicker"
    static let entryNote = "sb.entry.note"
    static let entryDate = "sb.entry.date"
    static let entryAccount = "sb.entry.account"
    /// One per row of the account picker sheet.
    static let entryAccountRow = "sb.entry.accountRow"
    static let entryDiscount = "sb.entry.discount"
    static let entryClaim = "sb.entry.claim"
    /// Text field inside the discount alert.
    static let entryDiscountField = "sb.entry.discountField"
    /// The transient toast that carries validation copy ("Missing Category").
    static let entryToast = "sb.entry.toast"
    /// Delete inside the edit form (immediate, unlike the row's undoable one).
    static let entryEditDelete = "sb.entry.editDelete"

    // MARK: - Number pad

    static func padDigit(_ digit: Int) -> String { "sb.pad.digit.\(digit)" }
    static let padDecimal = "sb.pad.decimal"
    static let padBackspace = "sb.pad.backspace"
    /// The trailing delete next to the amount, shown in "whole numbers" mode.
    static let padDelete = "sb.pad.delete"

    // MARK: - Smart entry sheet

    static let smartEntryClose = "sb.smartEntry.close"
    static let smartEntryField = "sb.smartEntry.field"
    /// The "→" parse button next to the field.
    static let smartEntryParse = "sb.smartEntry.parse"
    /// Parsed preview: container plus the two values the cases assert.
    static let smartEntryPreview = "sb.smartEntry.preview"
    static let smartEntryPreviewAmount = "sb.smartEntry.previewAmount"
    static let smartEntryPreviewCategory = "sb.smartEntry.previewCategory"
    /// "Fill the form" — fills the entry form without saving.
    static let smartEntryApply = "sb.smartEntry.apply"

    // MARK: - AI analysis sheet

    static let aiScreen = "sb.ai.screen"
    static let aiMessage = "sb.ai.message"
    static let aiClose = "sb.ai.close"

    // MARK: - Sidebar (iPad / Mac regular width)

    static func sidebarTab(_ tab: String) -> String { "sb.sidebar.\(tab)" }

    // MARK: - Accounts

    static let accountsAdd = "sb.accounts.addButton"
    static let accountsTransfer = "sb.accounts.transferButton"
    /// Total balance row above the list. Hidden and archived accounts are
    /// excluded from it, which is what the hide/archive cases assert.
    static let accountsTotal = "sb.accounts.total"
    static let accountsRow = "sb.accounts.row"
    static let accountsRowHide = "sb.accounts.row.hide"
    static let accountsRowArchive = "sb.accounts.row.archive"
    static let accountsHiddenToggle = "sb.accounts.hiddenToggle"
    static let accountsArchivedToggle = "sb.accounts.archivedToggle"
    static let accountsTransferRow = "sb.accounts.transferRow"

    static let accountName = "sb.account.name"
    static let accountOpeningBalance = "sb.account.openingBalance"
    static let accountKindPicker = "sb.account.kindPicker"
    static let accountCurrencyPicker = "sb.account.currencyPicker"
    static let accountSave = "sb.account.save"
    static let accountCancel = "sb.account.cancel"

    // MARK: - Transfer

    static let transferSource = "sb.transfer.source"
    static let transferDestination = "sb.transfer.destination"
    static let transferAmount = "sb.transfer.amount"
    static let transferFee = "sb.transfer.fee"
    static let transferDestinationAmount = "sb.transfer.destinationAmount"
    static let transferSave = "sb.transfer.save"
    static let transferCancel = "sb.transfer.cancel"

    // MARK: - App lock

    static let lockScreen = "sb.lock.screen"
    static let lockUnlockButton = "sb.lock.unlockButton"

    // MARK: - Export / restore

    static let exportJSONButton = "sb.export.jsonButton"
    /// Record counts of the payload just written. Export has no preview
    /// screen, so without this line a case can only assert "the sheet opened".
    static let exportSummary = "sb.export.summary"
    static let importBackupChooseFile = "sb.importBackup.chooseFile"
    /// The result card after a restore ("Imported 3 records.").
    static let importBackupResult = "sb.importBackup.result"

    // MARK: - Settings

    /// One per `SettingsRoute`, so a new screen gets an identifier for free.
    static func settingsRow(_ route: String) -> String { "sb.settings.row.\(route)" }
    static let settingsImportData = "sb.settings.importData"
    /// The chevron every settings sub-screen shares.
    static let settingsBack = "sb.settings.back"
    /// App Lock toggle (Settings → General → Authentication).
    static let settingsAppLockToggle = "sb.settings.row.authentication"
    /// "Save and Continue" toggle on the Number Entry screen.
    static let settingsContinuousEntryToggle = "sb.settings.continuousEntry"
    /// One per language row: `system` / `en` / `zh-Hans` / `zh-Hant`.
    static func settingsLanguageRow(_ code: String) -> String {
        "sb.settings.language.row.\(code.isEmpty ? "system" : code)"
    }
    static let settingsAppearancePicker = "sb.settings.appearance.theme"
    /// One per currency row (ISO code).
    static func settingsCurrencyRow(_ code: String) -> String { "sb.settings.currency.row.\(code)" }
    static let settingsCurrencyRates = "sb.settings.currency.rates"
    static let settingsNotificationEnable = "sb.settings.notifications.enable"
    static let settingsNotificationOption = "sb.settings.notifications.option"
    static let settingsNotificationCustomTime = "sb.settings.notifications.customTime"
    /// One per app-icon row; the file stem is the stable key ("AppIcon",
    /// "AppIcon1"…), the row's own label is brand copy.
    static func settingsAppIconRow(_ key: String) -> String { "sb.settings.appIcon.row.\(key)" }

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
