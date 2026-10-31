//
//  UITestFixture.swift
//  smartbud
//
//  DEBUG-only launch hooks for `SmartBudUITests`. Three problems made the
//  interaction matrix non-deterministic before this file existed:
//
//    1. The App Group store survives between cases, so "统计支出 +12.50"
//       depended on what the previous case left behind.
//    2. The App Group defaults survive too — a case that turns on App Lock
//       or switches the language changes every case that runs after it.
//    3. Every case had to build its own categories and accounts through the
//       UI before it could test anything, which made each case slower and
//       coupled to UI that the case is not about.
//
//  `-uiTestStore` answers all three: an in-memory store (nothing touches the
//  real App Group database) plus a defaults reset, so every launch starts
//  from the same state. `-uiTestSeed` additionally inserts the fixture below.
//
//  Release builds compile the whole file away; `SmartBudApp` and
//  `DataRepository` only call into it under `#if DEBUG`.
//

#if DEBUG
import Foundation
import SwiftData

enum UITestFixture {
    /// Fresh in-memory store, reported as a healthy configuration so the
    /// degraded-storage banner never covers the screen under test.
    static var isStoreRequested: Bool {
        ProcessInfo.processInfo.arguments.contains("-uiTestStore")
    }

    /// Insert the categories / accounts / rate below after the store opens.
    static var isSeedRequested: Bool {
        ProcessInfo.processInfo.arguments.contains("-uiTestSeed")
    }

    /// `-uiTestKeepDefaults`: keep what the previous launch wrote to the App
    /// Group defaults. Only the language case needs this — it verifies the
    /// switch on the next launch, which is where the app applies it.
    static var keepsDefaults: Bool {
        ProcessInfo.processInfo.arguments.contains("-uiTestKeepDefaults")
    }

    /// Force App Lock on for this launch. The Settings toggle authenticates
    /// with the device passcode first, and a CI simulator has none, so the
    /// lock could otherwise be neither enabled nor dismissed from a test.
    static var forcesAppLock: Bool {
        ProcessInfo.processInfo.arguments.contains("-uiTestLock")
    }

    /// Let one unlock attempt succeed without the system biometric/passcode
    /// sheet. Only meaningful together with `forcesAppLock`.
    static var unlocksWithoutPrompt: Bool {
        ProcessInfo.processInfo.arguments.contains("-uiTestUnlock")
    }

    /// Every case starts from the same settings. Only the App Group domain is
    /// cleared; the simulator's own locale and language stay untouched.
    /// `@MainActor` because the suite identifier lives on `DataRepository`,
    /// which is main-actor isolated.
    @MainActor
    static func resetDefaults() {
        UserDefaults(suiteName: DataRepository.appGroupID)?
            .removePersistentDomain(forName: DataRepository.appGroupID)
    }

    /// Where `-exportToDocuments` parks the JSON export so a later launch can
    /// import it. The app container survives a relaunch (only the store is in
    /// memory), which is what makes an export → import round trip testable
    /// without touching the system file picker.
    static var documentsBackupURL: URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("uitest-backup.json")
    }

    /// `-exportToDocuments`: keep a copy of the export at `documentsBackupURL`.
    static var exportsToDocuments: Bool {
        ProcessInfo.processInfo.arguments.contains("-exportToDocuments")
    }

    /// `-importBackupFromDocuments`: the restore button loads
    /// `documentsBackupURL` directly instead of presenting the file picker.
    static var importsFromDocuments: Bool {
        ProcessInfo.processInfo.arguments.contains("-importBackupFromDocuments")
    }

    // MARK: - Fixture

    /// Names are Chinese on purpose: the deep-link contract matches a category
    /// by name (`smartbud://add?category=餐饮`), and asserting on a name the
    /// test itself created would hide a matching regression.
    static let foodCategoryName = "餐饮"
    static let transportCategoryName = "交通"
    static let salaryCategoryName = "工资"
    static let cashAccountName = "现金"
    static let cardAccountName = "银行卡"
    static let foreignAccountName = "人民币"
    /// Test environment: `-AppleLocale en_US`, so the base currency is USD and
    /// a foreign account needs a rate to be usable at all.
    static let foreignCurrencyCode = "CNY"
    static let foreignCurrencyRate = 0.14

    /// Categories and accounts a case can rely on, plus one foreign-currency
    /// account for the cross-currency transfer case. No transaction, budget or
    /// transfer is seeded: those are what the cases under test create.
    static func seed(in context: ModelContext) {
        let food = CategoryModel(name: foodCategoryName, emoji: "🍜",
                                 colour: "#FF9500", income: false, order: 0)
        let transport = CategoryModel(name: transportCategoryName, emoji: "🚌",
                                      colour: "#34C759", income: false, order: 1)
        let salary = CategoryModel(name: salaryCategoryName, emoji: "💰",
                                   colour: "#007AFF", income: true, order: 2)

        let cash = AccountModel(name: cashAccountName, emoji: "💵",
                                colour: "#34C759", kind: 0, order: 0)
        let card = AccountModel(name: cardAccountName, emoji: "💳",
                                colour: "#007AFF", kind: 1, order: 1)
        let foreign = AccountModel(name: foreignAccountName, emoji: "🇨🇳",
                                   colour: "#FF3B30", kind: 0,
                                   currencyCode: foreignCurrencyCode, order: 2)

        let rate = CurrencyRate(code: foreignCurrencyCode, rate: foreignCurrencyRate)

        for category in [food, transport, salary] { context.insert(category) }
        for account in [cash, card, foreign] { context.insert(account) }
        context.insert(rate)
        try? context.save()
    }
}
#endif
