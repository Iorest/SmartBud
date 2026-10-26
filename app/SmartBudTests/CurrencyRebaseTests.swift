//
//  CurrencyRebaseTests.swift
//  SmartBudTests
//
//  Switching the base currency has to convert every frozen amount and rebuild
//  the rate table in one step. The maths lives in `CurrencyRebase`; these tests
//  pin the direction of the conversion (the easy thing to get backwards) and
//  the table rewrite.
//

import Testing
import Foundation
import SwiftData

@Suite("CurrencyRebase")
struct CurrencyRebaseTests {

    /// 1 USD = 7.2 CNY, 1 EUR = 7.8 CNY, base is CNY.
    private let cnyRates = ["USD": 7.2, "EUR": 7.8]

    @Test("Old base amounts are divided by the new base's rate")
    func factorDirection() throws {
        let plan = try CurrencyRebase.plan(from: "CNY", to: "USD", rates: cnyRates).get()

        // 100 CNY is about 13.89 USD, not 720 USD.
        #expect(abs(plan.factor - 1.0 / 7.2) < 1e-9)
        #expect(abs(100 * plan.factor - 13.888888) < 1e-5)
    }

    @Test("The rate table is re-expressed in the new base")
    func tableRewrite() throws {
        let plan = try CurrencyRebase.plan(from: "CNY", to: "USD", rates: cnyRates).get()

        #expect(plan.rates["USD"] == nil)                       // new base has no row
        #expect(plan.rates["CNY"] == 0.138889)                  // old base is now foreign
        #expect(plan.rates["EUR"] == 1.083333)                  // 7.8 / 7.2
    }

    @Test("Switching to a currency without a stored rate is refused")
    func missingRate() {
        let result = CurrencyRebase.plan(from: "CNY", to: "GBP", rates: cnyRates)
        #expect(result == .failure(.missingRate("GBP")))
    }

    @Test("Switching to the current base is a no-op")
    func sameCurrency() {
        #expect(CurrencyRebase.plan(from: "CNY", to: "CNY", rates: cnyRates) == .failure(.sameCurrency))
    }

    @Test("Codes are normalised before comparison")
    func caseInsensitive() throws {
        let plan = try CurrencyRebase.plan(from: "cny", to: "usd", rates: cnyRates).get()
        #expect(plan.oldBase == "CNY")
        #expect(plan.newBase == "USD")
    }

    @Test("A round trip returns to the original scale")
    func roundTrip() throws {
        let first = try CurrencyRebase.plan(from: "CNY", to: "USD", rates: cnyRates).get()
        let second = try CurrencyRebase.plan(from: "USD", to: "CNY", rates: first.rates).get()

        // 1 CNY → USD → CNY should be ~1 again; only the 6-decimal rate
        // rounding is allowed to show.
        #expect(abs(first.factor * second.factor - 1) < 1e-4)
    }

    @Test("Invalid rates are dropped instead of producing NaN")
    func dropsInvalidRates() throws {
        let plan = try CurrencyRebase.plan(
            from: "CNY", to: "USD",
            rates: ["USD": 7.2, "BAD": .nan, "ZERO": 0]
        ).get()

        #expect(plan.rates["BAD"] == nil)
        #expect(plan.rates["ZERO"] == nil)
        #expect(plan.rates.values.allSatisfy { $0.isFinite && $0 > 0 })
    }
}

@MainActor
@Suite("CurrencyRebase apply")
struct CurrencyRebaseApplicationTests {

    /// Held for the whole test: a released container invalidates its context.
    private let container: ModelContainer
    private var context: ModelContext { container.mainContext }

    init() throws {
        container = try ModelContainer(
            for: Schema([
                TransactionModel.self,
                CategoryModel.self,
                AccountModel.self,
                CurrencyRate.self,
                BudgetModel.self,
                MainBudgetModel.self,
                TemplateTransactionModel.self
            ]),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    @Test("Every stored amount is converted and the table is rebuilt")
    func convertsStoredAmounts() throws {

        // No account → the amount is a base-currency number and must move.
        let modern = TransactionModel(baseAmount: 100, amount: 100, date: .now)
        let legacy = TransactionModel(amount: 50, date: .now)      // no baseAmount
        let budget = BudgetModel(amount: 1000)
        let mainBudget = MainBudgetModel(amount: 2000)
        let template = TemplateTransactionModel(amount: 30)
        let usd = CurrencyRate(code: "USD", rate: 7.2)
        let eur = CurrencyRate(code: "EUR", rate: 7.8)
        for item in [modern, legacy, budget, mainBudget, template, usd, eur] as [any PersistentModel] {
            context.insert(item)
        }
        try context.save()

        let plan = try CurrencyRebase.plan(
            from: "CNY", to: "USD", rates: ["USD": 7.2, "EUR": 7.8]
        ).get()
        let result = try CurrencyRebaseService.apply(plan, context: context)

        #expect(result.transactions == 2)
        #expect(abs(modern.amount - 13.89) < 0.001)
        #expect(abs((modern.baseAmount ?? 0) - 13.89) < 0.001)
        #expect(abs(legacy.amount - 6.94) < 0.001)                // converted too
        #expect(abs((legacy.baseAmount ?? 0) - 6.94) < 0.001)     // materialised
        #expect(abs(budget.amount - 138.89) < 0.001)
        #expect(abs(mainBudget.amount - 277.78) < 0.001)
        #expect(abs(template.amount - 4.17) < 0.001)

        let rates = try context.fetch(FetchDescriptor<CurrencyRate>())
        #expect(rates.first { $0.code == "USD" } == nil)          // new base has no row
        #expect(rates.first { $0.code == "CNY" }?.rate == 0.138889)
        #expect(rates.first { $0.code == "EUR" }?.rate == 1.083333)
    }

    @Test("An account with its own currency keeps its amounts, only baseAmount moves")
    func keepsForeignAccountAmounts() throws {
        let account = AccountModel(name: "USD 账户", currencyCode: "USD", openingBalance: 0)
        context.insert(account)
        let local = TransactionModel(baseAmount: 720, amount: 100, date: .now)
        local.account = account
        context.insert(local)
        try context.save()

        // 1 SGD = 5.2271 CNY, so 100 USD (720 CNY) is about 137.73 SGD.
        let plan = try CurrencyRebase.plan(
            from: "CNY", to: "SGD", rates: ["SGD": 5.2271, "USD": 7.2]
        ).get()
        _ = try CurrencyRebaseService.apply(plan, context: context)

        // 100 USD stays 100 USD; only its base value moves.
        #expect(local.amount == 100)
        #expect(abs((local.baseAmount ?? 0) - 137.74) < 0.02)
    }

    @Test("Only an account that follows the base moves its opening balance")
    func convertsOpeningBalances() throws {
        let following = AccountModel(name: "现金", currencyCode: "", openingBalance: 1000)
        let explicit = AccountModel(name: "USD 账户", currencyCode: "USD", openingBalance: 100)
        context.insert(following)
        context.insert(explicit)
        try context.save()

        let plan = try CurrencyRebase.plan(from: "CNY", to: "USD", rates: ["USD": 7.2]).get()
        _ = try CurrencyRebaseService.apply(plan, context: context)

        #expect(abs(following.openingBalance - 138.89) < 0.001)
        #expect(explicit.openingBalance == 100)
    }

    @Test("A transfer converts each side only when that account follows the base")
    func convertsTransferSides() throws {
        let cash = AccountModel(name: "现金", currencyCode: "", openingBalance: 0)
        let wallet = AccountModel(name: "零钱", currencyCode: "", openingBalance: 0)
        let usd = AccountModel(name: "USD 账户", currencyCode: "USD", openingBalance: 0)
        for account in [cash, wallet, usd] { context.insert(account) }

        // 720 CNY left a base account and 100 USD landed in an explicit one.
        let cross = TransferModel(amount: 720, destinationAmount: 100, fee: 7.2,
                                  date: .now, source: cash, destination: usd)
        // Same-currency transfer: both sides are base numbers.
        let plain = TransferModel(amount: 100, destinationAmount: 0, fee: 0,
                                  date: .now, source: cash, destination: wallet)
        context.insert(cross)
        context.insert(plain)
        try context.save()

        let plan = try CurrencyRebase.plan(from: "CNY", to: "USD", rates: ["USD": 7.2]).get()
        _ = try CurrencyRebaseService.apply(plan, context: context)

        #expect(abs(cross.amount - 100) < 0.001)          // source follows base
        #expect(cross.destinationAmount == 100)            // USD side untouched
        #expect(abs(cross.fee - 1) < 0.001)
        #expect(abs(plain.amount - 13.89) < 0.001)
    }

    @Test("A transaction on a base-currency account moves its amount as well")
    func convertsBaseCurrencyAccountAmounts() throws {
        let account = AccountModel(name: "现金", currencyCode: "", openingBalance: 0)
        context.insert(account)
        let local = TransactionModel(baseAmount: 100, amount: 100, date: .now)
        local.account = account
        context.insert(local)
        try context.save()

        let plan = try CurrencyRebase.plan(
            from: "CNY", to: "USD", rates: ["USD": 7.2]
        ).get()
        _ = try CurrencyRebaseService.apply(plan, context: context)

        #expect(abs(local.amount - 13.89) < 0.001)
        #expect(abs((local.baseAmount ?? 0) - 13.89) < 0.001)
    }
}

// MARK: - Base currency storage

/// The base currency used to live only in the device locale: the key was
/// written when the user switched currency, so a fresh install had nothing in
/// `UserDefaults` and every raw read (export, widgets, importer check) saw an
/// empty value. These tests pin the fallback, the one-time pin, and the export.
@Suite("Base currency storage")
struct BaseCurrencyStorageTests {

    /// A private suite, so the test never reads or writes the app group.
    private struct Scratch {
        let name: String
        let defaults: UserDefaults

        init() {
            name = "SmartBudTests.baseCurrency.\(UUID().uuidString)"
            defaults = UserDefaults(suiteName: name)!
        }

        func cleanUp() { defaults.removePersistentDomain(forName: name) }
    }

    private var localeCode: String {
        let device = Locale.current.currency?.identifier ?? ""
        return device.isEmpty ? "USD" : device
    }

    @Test("An absent or blank key falls back to the device locale")
    func fallsBackToLocale() {
        let scratch = Scratch()
        defer { scratch.cleanUp() }

        #expect(AppBaseCurrency.code(in: scratch.defaults) == localeCode)
        scratch.defaults.set("   ", forKey: AppBaseCurrency.storedKey)
        #expect(AppBaseCurrency.code(in: scratch.defaults) == localeCode)
    }

    @Test("A stored code wins and is trimmed")
    func storedCodeWins() {
        let scratch = Scratch()
        defer { scratch.cleanUp() }

        scratch.defaults.set("  jpy ", forKey: AppBaseCurrency.storedKey)
        #expect(AppBaseCurrency.code(in: scratch.defaults) == "jpy")
    }

    @Test("Pinning writes the effective code once and keeps a real choice")
    func pinning() {
        let scratch = Scratch()
        defer { scratch.cleanUp() }

        let pinned = AppBaseCurrency.pin(in: scratch.defaults)
        #expect(pinned == localeCode)
        #expect(scratch.defaults.string(forKey: AppBaseCurrency.storedKey) == pinned)

        // A second launch must not rewrite a code the user chose.
        scratch.defaults.set("JPY", forKey: AppBaseCurrency.storedKey)
        #expect(AppBaseCurrency.pin(in: scratch.defaults) == "JPY")
        #expect(scratch.defaults.string(forKey: AppBaseCurrency.storedKey) == "JPY")
    }

    @Test("A backup always names a base currency, even on a fresh install")
    func exportNamesBaseCurrency() {
        let scratch = Scratch()
        defer { scratch.cleanUp() }

        let settings = ExportSchema.SettingsDTO.current(defaults: scratch.defaults)

        #expect(settings.baseCurrency == AppBaseCurrency.code(in: scratch.defaults))
        #expect(!(settings.baseCurrency ?? "").isEmpty)
    }
}
