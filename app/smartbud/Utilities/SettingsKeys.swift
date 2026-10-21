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
    static let sectionGeneral = "settings.section.general"
    static let sectionAppearance = "settings.section.appearance"
    static let sectionData = "settings.section.data"
    static let sectionOthers = "settings.section.others"

    // MARK: - Pro card

    static let proTitle = "settings.pro.title"
    static let proSubtitle = "settings.pro.subtitle"

    // Subscription screen — required disclosures for App Store Guideline 3.1.2.
    // `proLegalBody` and `proLegalAgree` are kept as single strings (no
    // inline link markup) so the view can lay out the two legal links
    // (Terms of Use / Privacy Policy) as proper tappable SwiftUI `Text`
    // segments rather than parsing a Markdown blob at runtime.
    static let proLegalBody = "settings.pro.legal.body"
    static let proLegalAgree = "settings.pro.legal.agree"
    static let proTermsOfUse = "settings.pro.termsOfUse"
    static let proPrivacyPolicy = "settings.pro.privacyPolicy"
    static let proManageSubscription = "settings.pro.manage"
    static let proErrorTitle = "settings.pro.error.title"
    static let proErrorPurchase = "settings.pro.error.purchase"
    static let proErrorLoad = "settings.pro.error.load"
    static let proErrorRestore = "settings.pro.error.restore"
    static let proErrorDismiss = "settings.pro.error.dismiss"
    static let proLimitedFreeTitle = "settings.pro.limitedFreeTitle"
    static let proLimitedFreeSubtitle = "settings.pro.limitedFreeSubtitle"

    // Subscription screen — group headers and the lifetime-specific
    // disclosures. The auto-renewal text in `proLegalBody` covers the
    // three subscription SKUs; the lifetime section needs its own one-
    // line disclosure because non-consumable IAPs have no auto-renewal
    // and no subscription to manage.
    static let proSectionSubscriptions = "settings.pro.section.subscriptions"
    static let proSectionLifetime = "settings.pro.section.lifetime"
    static let proLifetimeOneTime = "settings.pro.lifetime.oneTime"
    static let proLifetimeLegalBody = "settings.pro.lifetime.legal.body"

    // MARK: - Erase all data

    static let eraseTitle = "settings.erase.title"
    static let eraseSuccess = "settings.erase.success"
    static let erasePartial = "settings.erase.partial"
    static let eraseFailure = "settings.erase.failure"

    // MARK: - Export data (GDPR Article 20)

    static let exportTitle = "settings.export.title"
    static let exportSubtitle = "settings.export.subtitle"
    static let exportAction = "settings.export.action"
    static let exportProgress = "settings.export.progress"
    static let exportFailure = "settings.export.failure"
    static let exportEmpty = "settings.export.empty"

    // MARK: - Banner (offline / fallback mode)

    static let bannerFallbackTitle = "settings.banner.fallbackTitle"
    static let bannerFallbackBody = "settings.banner.fallbackBody"

    // MARK: - Row titles (General)

    static let rowNotifications = "settings.row.notifications"
    static let rowCurrency = "settings.row.currency"
    static let rowNumberEntry = "settings.row.numberEntry"
    static let rowAuthentication = "settings.row.authentication"
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
    static let rowTemplates = "settings.row.templates"
    static let rowImportData = "settings.row.importData"
    static let rowExportData = "settings.row.exportData"
    static let rowEraseData = "settings.row.eraseData"

    // MARK: - Row titles (Others)

    static let rowHaptics = "settings.row.haptics"
    static let rowReportBug = "settings.row.reportBug"
    static let rowFeatureRequest = "settings.row.featureRequest"
    static let rowRateAppStore = "settings.row.rateAppStore"

    // MARK: - Optional text values shown on the right side of a row

    static let themeLight = "settings.theme.light"
    static let themeDark = "settings.theme.dark"
    static let themeSystem = "settings.theme.system"
    static let notificationMornings = "settings.notification.mornings"
    static let notificationEvenings = "settings.notification.evenings"
    static let notificationCustom = "settings.notification.custom"
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

    // MARK: - Generic alerts / buttons

}
