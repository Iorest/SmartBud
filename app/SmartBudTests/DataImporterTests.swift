//
//  DataImporterTests.swift
//  SmartBudTests
//
//  Merge rules of `DataImporter` against a real (in-memory) SwiftData store:
//  relationships, idempotency, settings, and the values it refuses.
//

import Testing
import Foundation
import SwiftData

/// One in-memory store per test, held for the whole test so the container
/// outlives the context (a released container invalidates it).
@MainActor
struct ImportFixture {

/// One in-memory store per test, held for the whole test so the
/// container outlives the context (a released container invalidates it).
let container: ModelContainer
var context: ModelContext { container.mainContext }

init() throws {
    container = try ModelContainer(
        for: Schema([
            TransactionModel.self,
            CategoryModel.self,
            AccountModel.self,
            TransferModel.self,
            CurrencyRate.self,
            BudgetModel.self,
            MainBudgetModel.self,
            TemplateTransactionModel.self
        ]),
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
}

func payload(
    categories: [ExportSchema.CategoryDTO] = [],
    accounts: [ExportSchema.AccountDTO] = [],
    transactions: [ExportSchema.TransactionDTO] = [],
    transfers: [ExportSchema.TransferDTO] = [],
    budgets: [ExportSchema.BudgetDTO] = [],
    mainBudgets: [ExportSchema.MainBudgetDTO] = [],
    templates: [ExportSchema.TemplateTransactionDTO] = [],
    rates: [ExportSchema.RateDTO] = [],
    settings: ExportSchema.SettingsDTO? = nil
) -> ExportSchema.Payload {
    ExportSchema.Payload(
        exportDate: .now, appVersion: "test", schemaVersion: ExportSchema.version,
        transactions: transactions, categories: categories, budgets: budgets,
        mainBudgets: mainBudgets, templates: templates, accounts: accounts,
        transfers: transfers, rates: rates, settings: settings
    )
}

/// The importer reads the device's base currency from the app group.
/// Tests set it explicitly and restore whatever was there.
func withBaseCurrency(_ code: String, _ body: () throws -> Void) rethrows {
    let defaults = UserDefaults.appGroup
    let previous = defaults.string(forKey: "currency")
    defaults.set(code, forKey: "currency")
    defer {
        if let previous {
            defaults.set(previous, forKey: "currency")
        } else {
            defaults.removeObject(forKey: "currency")
        }
    }
    try body()
}

let categoryID = UUID()
let accountID = UUID()

var sampleCategory: ExportSchema.CategoryDTO {
    .init(id: categoryID, name: "餐饮", emoji: "🍜", colour: "#FF0000",
          income: false, order: 0, dateCreated: .now)
}

var sampleAccount: ExportSchema.AccountDTO {
    .init(id: accountID, name: "招行", emoji: "💳", colour: "#279AF4", kind: 1,
          openingBalance: 1000, hidden: false, order: 0, dateCreated: .now,
          currencyCode: "CNY", archived: false)
}
}

@MainActor
@Suite("DataImporter")
struct DataImporterTests {

    private let fixture: ImportFixture

    init() throws {
        fixture = try ImportFixture()
    }

    @Test("Transactions resolve their category and account by id")
    func resolvesRelationshipsByID() throws {
        let transaction = ExportSchema.TransactionDTO(
            id: UUID(), amount: 32.5, date: .now, day: nil, month: nil,
            note: "午饭", income: false, recurringType: 0, recurringCoefficient: 0,
            onceRecurring: false, categoryId: fixture.categoryID, categoryName: "餐饮",
            accountId: fixture.accountID, accountName: "招行", baseAmount: 32.5,
            accountCurrency: "CNY", discount: 5, reimbursable: true,
            reimbursedAt: nil, adjustment: false
        )

        let summary = try DataImporter.apply(
            fixture.payload(categories: [fixture.sampleCategory], accounts: [fixture.sampleAccount],
                    transactions: [transaction]),
            context: fixture.context
        )

        #expect(summary.categories == 1)
        #expect(summary.accounts == 1)
        #expect(summary.transactions == 1)

        let stored = try fixture.context.fetch(FetchDescriptor<TransactionModel>())
        #expect(stored.count == 1)
        #expect(stored.first?.category?.id == fixture.categoryID)
        #expect(stored.first?.account?.id == fixture.accountID)
        #expect(stored.first?.discount == 5)
        #expect(stored.first?.reimbursable == true)
        #expect(stored.first?.isPendingReimbursement == true)
    }

    @Test("A missing category id falls back to the stored name")
    func fallsBackToCategoryName() throws {
        let transaction = ExportSchema.TransactionDTO(
            id: UUID(), amount: 10, date: .now, day: nil, month: nil,
            note: "", income: false, recurringType: 0, recurringCoefficient: 0,
            onceRecurring: false, categoryId: UUID(), categoryName: "餐饮",
            accountId: nil, accountName: nil, baseAmount: nil,
            accountCurrency: nil, discount: nil, reimbursable: nil,
            reimbursedAt: nil, adjustment: nil
        )

        _ = try DataImporter.apply(
            fixture.payload(categories: [fixture.sampleCategory], transactions: [transaction]),
            context: fixture.context
        )

        let stored = try fixture.context.fetch(FetchDescriptor<TransactionModel>())
        #expect(stored.first?.category?.name == "餐饮")
    }

    @Test("Importing the same file twice changes nothing")
    func isIdempotent() throws {
        let transaction = ExportSchema.TransactionDTO(
            id: UUID(), amount: 10, date: .now, day: nil, month: nil,
            note: "coffee", income: false, recurringType: 0, recurringCoefficient: 0,
            onceRecurring: false, categoryId: fixture.categoryID, categoryName: "餐饮",
            accountId: fixture.accountID, accountName: "招行", baseAmount: 10,
            accountCurrency: "CNY", discount: nil, reimbursable: nil,
            reimbursedAt: nil, adjustment: nil
        )
        let file = fixture.payload(categories: [fixture.sampleCategory], accounts: [fixture.sampleAccount],
                           transactions: [transaction])

        let first = try DataImporter.apply(file, context: fixture.context)
        let second = try DataImporter.apply(file, context: fixture.context)

        #expect(first.imported == 3)
        #expect(second.imported == 0)
        #expect(second.skipped == 3)

        let stored = try fixture.context.fetch(FetchDescriptor<TransactionModel>())
        #expect(stored.count == 1)
    }

    @Test("A transfer with an unknown account is skipped, not orphaned")
    func skipsOrphanTransfer() throws {
        let transfer = ExportSchema.TransferDTO(
            id: UUID(), amount: 50, date: .now, note: nil,
            sourceId: fixture.accountID, sourceName: "招行",
            destinationId: UUID(), destinationName: "不存在的账户",
            destinationAmount: nil, fee: nil
        )

        let summary = try DataImporter.apply(
            fixture.payload(accounts: [fixture.sampleAccount], transfers: [transfer]),
            context: fixture.context
        )

        #expect(summary.transfers == 0)
        #expect(summary.skipped == 1)
        #expect(try fixture.context.fetch(FetchDescriptor<TransferModel>()).isEmpty)
    }

    @Test("Transfer fee and received amount survive the round trip")
    func keepsTransferFee() throws {
        let second = ExportSchema.AccountDTO(
            id: UUID(), name: "美元账户", emoji: "💵", colour: "#00AA00", kind: 1,
            openingBalance: 0, hidden: false, order: 1, dateCreated: .now,
            currencyCode: "USD", archived: false
        )
        let transfer = ExportSchema.TransferDTO(
            id: UUID(), amount: 100, date: .now, note: "汇款",
            sourceId: fixture.accountID, sourceName: "招行",
            destinationId: second.id, destinationName: "美元账户",
            destinationAmount: 13.75, fee: 2.5
        )

        _ = try DataImporter.apply(
            fixture.payload(accounts: [fixture.sampleAccount, second], transfers: [transfer]),
            context: fixture.context
        )

        let stored = try fixture.context.fetch(FetchDescriptor<TransferModel>()).first
        #expect(stored?.fee == 2.5)
        #expect(stored?.destinationAmount == 13.75)
        #expect(stored?.outgoingTotal == 102.5)
        #expect(stored?.receivedAmount == 13.75)
    }

    @Test("A schema 3 file without transfers or rates still decodes")
    func decodesOlderFile() throws {
        let json = """
        {
          "exportDate": "2026-01-02T03:04:05Z",
          "appVersion": "3.0",
          "schemaVersion": 3,
          "transactions": [],
          "categories": [],
          "budgets": [],
          "mainBudgets": [],
          "templates": [],
          "accounts": []
        }
        """
        let file = try DataImporter.decode(Data(json.utf8))

        #expect(file.schemaVersion == 3)
        #expect(file.transfers.isEmpty)
        #expect(file.rates.isEmpty)
    }

    @Test("An empty device adopts the backup's settings")
    func adoptsSettingsWhenEmpty() throws {
        try fixture.withBaseCurrency("USD") {
            let settings = ExportSchema.SettingsDTO(
                baseCurrency: "CNY", firstDayOfMonth: 15, firstWeekday: 2)
            let summary = try DataImporter.apply(
                fixture.payload(settings: settings), context: fixture.context)

            #expect(summary.settingsToApply?.baseCurrency == "CNY")
            #expect(summary.settingsToApply?.firstDayOfMonth == 15)
        }
    }

    @Test("Restoring into another base currency is refused, not reinterpreted")
    func refusesBaseCurrencyMismatch() throws {
        try fixture.withBaseCurrency("USD") {
            fixture.context.insert(TransactionModel(amount: 10, date: .now))
            let settings = ExportSchema.SettingsDTO(
                baseCurrency: "CNY", firstDayOfMonth: nil, firstWeekday: nil)

            #expect {
                _ = try DataImporter.apply(fixture.payload(settings: settings), context: fixture.context)
            } throws: { error in
                guard case DataImporter.ImportError.baseCurrencyMismatch(let backup, let local) = error else {
                    return false
                }
                return backup == "CNY" && local == "USD"
            }
        }
    }

    @Test("Same base currency keeps the device's own period settings")
    func keepsLocalSettingsWhenBaseMatches() throws {
        try fixture.withBaseCurrency("CNY") {
            fixture.context.insert(TransactionModel(amount: 10, date: .now))
            let settings = ExportSchema.SettingsDTO(
                baseCurrency: "CNY", firstDayOfMonth: 15, firstWeekday: 2)

            let summary = try DataImporter.apply(fixture.payload(settings: settings), context: fixture.context)
            #expect(summary.settingsToApply == nil)
        }
    }

    @Test("A backup without settings applies nothing")
    func noSettingsMeansNoChange() throws {
        let summary = try DataImporter.apply(fixture.payload(), context: fixture.context)
        #expect(summary.settingsToApply == nil)
    }

    @Test("A backup written by a newer app version is refused")
    func rejectsNewerSchema() {
        let future = Data("{\"schemaVersion\": 99, \"transactions\": []}".utf8)
        #expect(throws: DataImporter.ImportError.self) {
            _ = try DataImporter.decode(future)
        }
    }

    @Test("Corrupt amounts are clamped and bad rates are skipped")
    func sanitizesValues() throws {
        let transaction = ExportSchema.TransactionDTO(
            id: UUID(), amount: -5, date: .now, day: nil, month: nil,
            note: "", income: false, recurringType: 0, recurringCoefficient: 0,
            onceRecurring: false, categoryId: nil, categoryName: nil,
            accountId: nil, accountName: nil, baseAmount: .infinity,
            accountCurrency: nil, discount: 1e12, reimbursable: nil,
            reimbursedAt: nil, adjustment: nil
        )
        let badRate = ExportSchema.RateDTO(code: "USD", rate: 0, updatedAt: .now)

        let summary = try DataImporter.apply(
            fixture.payload(transactions: [transaction], rates: [badRate]),
            context: fixture.context
        )

        let stored = try fixture.context.fetch(FetchDescriptor<TransactionModel>()).first
        #expect(stored?.amount == 0)
        #expect(stored?.baseAmount == 0)
        #expect(stored?.discount == Money.maxAmount)
        #expect(try fixture.context.fetch(FetchDescriptor<CurrencyRate>()).isEmpty)
        #expect(summary.skipped == 1)
    }

    @Test("A file that is not a backup is rejected")
    func rejectsForeignFile() {
        let notBackup = Data("{\"hello\":1}".utf8)
        #expect(throws: DataImporter.ImportError.self) {
            _ = try DataImporter.decode(notBackup)
        }
    }

    @Test("Undo snapshots keep every field the editor can write")
    func snapshotRoundTripsEverything() throws {
        let category = CategoryModel(name: "餐饮", emoji: "🍜", colour: "#FF0000")
        fixture.context.insert(category)
        let account = AccountModel(name: "招行", currencyCode: "CNY", openingBalance: 100)
        fixture.context.insert(account)

        let original = TransactionModel(
            note: "午餐", category: category, account: account, baseAmount: 42.5,
            income: false, amount: 42.5, date: .now,
            discount: 5, reimbursable: true, adjustment: false
        )
        original.reimbursedAt = Date(timeIntervalSince1970: 1_700_000_000)
        fixture.context.insert(original)

        let restored = TransactionSnapshot(original).makeTransaction()

        #expect(restored.account?.id == account.id)
        #expect(restored.baseAmount == 42.5)
        #expect(restored.discount == 5)
        #expect(restored.reimbursable)
        #expect(restored.reimbursedAt == original.reimbursedAt)
        #expect(!restored.adjustment)
        #expect(restored.id == original.id)
    }

    @Test("Archived accounts stay archived and out of the visible list")
    func keepsArchivedFlag() throws {
        let archived = ExportSchema.AccountDTO(
            id: UUID(), name: "旧卡", emoji: "💳", colour: "#999999", kind: 1,
            openingBalance: 0, hidden: false, order: 2, dateCreated: .now,
            currencyCode: "CNY", archived: true
        )

        _ = try DataImporter.apply(fixture.payload(accounts: [archived]), context: fixture.context)

        let stored = try fixture.context.fetch(FetchDescriptor<AccountModel>())
        #expect(stored.first?.archived == true)
    }
}
