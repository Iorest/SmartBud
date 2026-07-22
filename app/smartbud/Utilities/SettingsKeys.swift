//
//  SettingsKeys.swift
//  smartbud
//
//  Semantic localization keys for the Settings screen and its subviews.
//  Call sites should reference these constants instead of inlining English
//  text, so that the String Catalog stays the single source of truth for
//  what each user-facing string says in every language.
//
//  The actual translations live in `app/Localizations/Localizable.xcstrings`
//  (key: the value of each `static let` here; en / zh-Hans / zh-Hant
//  values: the per-language user-facing text).
//
//  Naming convention: `settings.<area>.<element>` for the Settings screen
//  itself, and `<area>.<element>` (e.g. `export.csv.header`,
//  `alert.ok`) for shared widgets used elsewhere. Keys are dot-separated
//  so they're easy to grep and don't look like real English.
//

import Foundation

enum SettingsKey {
    // MARK: - Title and section headers

    static let title = "settings.title"
    static let sectionPro = "settings.section.pro"
    static let sectionGeneral = "settings.section.general"
    static let sectionAppearance = "settings.section.appearance"
    static let sectionData = "settings.section.data"
    static let sectionOthers = "settings.section.others"

    // MARK: - Pro card

    static let proTitle = "settings.pro.title"
    static let proSubtitle = "settings.pro.subtitle"

    // MARK: - Row titles (General)

    static let rowNotifications = "settings.row.notifications"
    static let rowCurrency = "settings.row.currency"
    static let rowNumberEntry = "settings.row.numberEntry"
    static let rowAuthentication = "settings.row.authentication"
    static let rowIncomeTracking = "settings.row.incomeTracking"
    static let rowTimeFrames = "settings.row.timeFrames"

    // MARK: - Row titles (Appearance)

    static let rowTheme = "settings.row.theme"
    static let rowAppIcon = "settings.row.app.icon"
    static let rowLanguage = "settings.row.language"
    static let rowDisplayCents = "settings.row.displayCents"
    static let rowUpcomingLogs = "settings.row.upcomingLogs"
    static let rowDisplaySign = "settings.row.displaySign"
    static let rowAnimatedCharts = "settings.row.animatedCharts"

    // MARK: - Row titles (Data)

    static let rowCategories = "settings.row.categories"
    static let rowICloudSync = "settings.row.iCloudSync"
    static let rowImportData = "settings.row.importData"
    static let rowExportData = "settings.row.exportData"
    static let rowEraseData = "settings.row.eraseData"

    // MARK: - Row titles (Others)

    static let rowHaptics = "settings.row.haptics"
    static let rowFeatureLab = "settings.row.featureLab"
    static let rowReportBug = "settings.row.reportBug"
    static let rowFeatureRequest = "settings.row.featureRequest"
    static let rowRateAppStore = "settings.row.rateAppStore"

    // MARK: - Optional text values shown on the right side of a row

    static let themeLight = "settings.theme.light"
    static let themeDark = "settings.theme.dark"
    static let themeSystem = "settings.theme.system"
    static let weekdaySunday = "settings.weekday.sunday"
    static let weekdayMonday = "settings.weekday.monday"
    static let notificationMornings = "settings.notification.mornings"
    static let notificationEvenings = "settings.notification.evenings"
    static let notificationCustom = "settings.notification.custom"
    static let toggleOn = "settings.toggle.on"
    static let toggleOff = "settings.toggle.off"
    static let numberEntryType1 = "settings.numberEntry.type1"
    static let numberEntryType2 = "settings.numberEntry.type2"
    static let upcomingShown = "settings.upcoming.shown"
    static let upcomingHidden = "settings.upcoming.hidden"
    static let hapticsNone = "settings.haptics.none"
    static let hapticsSubtle = "settings.haptics.subtle"
    static let hapticsExcessive = "settings.haptics.excessive"
    static let iconDeepSea = "settings.icon.deepSea"
    static let iconMidnight = "settings.icon.midnight"
    static let iconPlum = "settings.icon.plum"
    static let iconIndigo = "settings.icon.indigo"
    static let iconSky = "settings.icon.sky"
    static let iconSunset = "settings.icon.sunset"
    static let iconAqua = "settings.icon.aqua"
}

enum L10n {
    // MARK: - Language picker (used by SettingsViewModel.displayName(for:))

    static let languageSystem = "settings.language.system"
    static let languageEnglish = "settings.language.english"
    static let languageSimplifiedChinese = "settings.language.simplifiedChinese"
    static let languageTraditionalChinese = "settings.language.traditionalChinese"

    // MARK: - CSV export

    static let exportCsvHeader = "export.csv.header"
    static let exportTypeIncome = "export.type.income"
    static let exportTypeExpense = "export.type.expense"
    static let exportFailed = "export.failed"

    // MARK: - Generic alerts / buttons

    static let alertOk = "alert.ok"
}
