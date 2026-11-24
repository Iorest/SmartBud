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
            BookModel.self,
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
    books: [ExportSchema.BookDTO] = [],
    settings: ExportSchema.SettingsDTO? = nil
) -> ExportSchema.Payload {
    ExportSchema.Payload(
        exportDate: .now, appVersion: "test", schemaVersion: ExportSchema.version,
        transactions: transactions, categories: categories, budgets: budgets,
        mainBudgets: mainBudgets, templates: templates, accounts: accounts,
        transfers: transfers, rates: rates, books: books, settings: settings
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
        #expect(stored?.outgoingTotal == 100)   // the fee is its own row
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

@MainActor
@Suite("Import rates")
struct ImportRateMergeTests {
    private let fixture: ImportFixture

    init() throws { fixture = try ImportFixture() }

    @Test("An imported backup adds missing rates but never replaces local ones")
    func ratesMergeWithoutClobbering() throws {
        fixture.context.insert(CurrencyRate(code: "USD", rate: 7.2))
        try fixture.context.save()

        let summary = try DataImporter.apply(
            fixture.payload(rates: [
                ExportSchema.RateDTO(code: "USD", rate: 6.0, updatedAt: .now),
                ExportSchema.RateDTO(code: "EUR", rate: 7.8, updatedAt: .now)
            ]),
            context: fixture.context
        )

        let rates = try fixture.context.fetch(FetchDescriptor<CurrencyRate>())
        #expect(rates.first { $0.code == "USD" }?.rate == 7.2)
        #expect(rates.first { $0.code == "EUR" }?.rate == 7.8)
        #expect(summary.rates == 1)
        #expect(summary.skipped == 1)
    }
}

// MARK: - Books (TELE-20)

@MainActor
@Suite("Book model and migration")
struct BookMigrationTests {
    private let fixture: ImportFixture

    init() throws { fixture = try ImportFixture() }

    /// The current book lives in shared defaults; do not leak a test value
    /// into the next suite.
    private func withCleanSelection(_ body: () throws -> Void) rethrows {
        let defaults = UserDefaults.appGroup
        let previous = defaults.string(forKey: BookSelection.key)
        defaults.removeObject(forKey: BookSelection.key)
        defer {
            if let previous {
                defaults.set(previous, forKey: BookSelection.key)
            } else {
                defaults.removeObject(forKey: BookSelection.key)
            }
        }
        try body()
    }

    @Test("Legacy single-book data keeps its monthly, budget and balance numbers")
    func legacyNumbersUnchanged() throws {
        let calendar = Calendar(identifier: .gregorian)
        let month = calendar.date(from: DateComponents(year: 2026, month: 11, day: 1))!
        let account = AccountModel(name: "Cash", currencyCode: "CNY", openingBalance: 1_000)
        let category = CategoryModel(name: "Food", emoji: "🍜", colour: "#FF0000")
        let expense = TransactionModel(note: "lunch", category: category, account: account,
                                       baseAmount: 42.5, amount: 42.5,
                                       date: calendar.date(byAdding: .day, value: 1, to: month)!)
        let salary = TransactionModel(note: "salary", account: account, income: true,
                                      baseAmount: 2_000, amount: 2_000, date: month)
        let budget = BudgetModel(amount: 500, startDate: month, type: 3)
        let mainBudget = MainBudgetModel(amount: 2_500, startDate: month, type: 3)
        let template = TemplateTransactionModel(note: "coffee", amount: 10)

        // Exactly what a pre-book build left behind: no book id anywhere.
        account.bookID = nil
        category.bookID = nil
        expense.bookID = nil
        salary.bookID = nil
        budget.bookID = nil
        mainBudget.bookID = nil
        template.bookID = nil
        fixture.context.insert(account)
        fixture.context.insert(category)
        fixture.context.insert(expense)
        fixture.context.insert(salary)
        fixture.context.insert(budget)
        fixture.context.insert(mainBudget)
        fixture.context.insert(template)
        try fixture.context.save()

        func snapshot() -> (spend: Double, income: Double, budgetLeft: Double, balance: Double) {
            let rows = (try? fixture.context.fetch(FetchDescriptor<TransactionModel>())) ?? []
            let range = AppPeriod.monthRange(containing: month, startDay: 1, calendar: calendar)
            let monthly = rows.filter { $0.wrappedDate >= range.start && $0.wrappedDate < range.end }
            let spend = monthly.reduce(0) { $0 + $1.spendBaseAmount }
            let income = monthly.reduce(0) { $0 + ($1.countsAsIncome ? $1.wrappedBaseAmount : 0) }
            let balance = AccountBalance.current(
                opening: account.openingBalance,
                transactions: rows.map { (amount: $0.amount, income: $0.income, isRefund: $0.isRefund) })
            return (spend, income, budget.amount - spend, balance)
        }

        let before = snapshot()
        try withCleanSelection {
            let written = BookMigration.migrate(in: fixture.context)
            #expect(written == 8)  // the default book plus seven legacy rows
            #expect(BookMigration.migrate(in: fixture.context) == 0)
            #expect(BookSelection.current() == BookModel.defaultID)
        }
        let after = snapshot()

        #expect(before.spend == 42.5)
        #expect(before.income == 2_000)
        #expect(before.budgetLeft == 457.5)
        #expect(before.balance == 2_957.5)
        #expect(after.spend == before.spend)
        #expect(after.income == before.income)
        #expect(after.budgetLeft == before.budgetLeft)
        #expect(after.balance == before.balance)

        let books = try fixture.context.fetch(FetchDescriptor<BookModel>())
        #expect(books.count == 1)
        #expect(books.first?.id == BookModel.defaultID)
        #expect(books.first?.name == BookModel.defaultName)
        #expect(expense.bookID == BookModel.defaultID)
        #expect(salary.bookID == BookModel.defaultID)
        #expect(budget.bookID == BookModel.defaultID)
        #expect(mainBudget.bookID == BookModel.defaultID)
        #expect(template.bookID == BookModel.defaultID)
        #expect(category.bookID == BookModel.defaultID)
        #expect(account.bookID == BookModel.defaultID)
    }

    @Test("Two books are isolated by a bookID query")
    func booksAreIsolated() throws {
        let firstBook = UUID()
        let secondBook = UUID()
        let first = TransactionModel(note: "first", amount: 10, bookID: firstBook)
        let second = TransactionModel(note: "second", amount: 20, bookID: secondBook)
        fixture.context.insert(first)
        fixture.context.insert(second)
        try fixture.context.save()

        let inFirst = try fixture.context.fetch(
            FetchDescriptor<TransactionModel>(predicate: #Predicate { $0.bookID == firstBook }))
        let inSecond = try fixture.context.fetch(
            FetchDescriptor<TransactionModel>(predicate: #Predicate { $0.bookID == secondBook }))

        #expect(inFirst.map(\.note) == ["first"])
        #expect(inSecond.map(\.note) == ["second"])
        #expect(BookScope.matches(first.bookID, selected: firstBook))
        #expect(!BookScope.matches(first.bookID, selected: secondBook))
        #expect(BookScope.matches(nil, selected: BookModel.defaultID))  // legacy row
        #expect(!BookScope.matches(nil, selected: secondBook))
    }

    @Test("A multi-book backup restores its whole book structure")
    func multiBookRoundTrip() throws {
        let travelCreated = Date(timeIntervalSince1970: 1_700_000_000)
        let travelID = UUID()
        let categoryID = UUID()
        let defaultBook = ExportSchema.BookDTO(id: BookModel.defaultID,
                                               name: BookModel.defaultName, icon: "",
                                               type: 0, order: 0, archived: false)
        let travel = ExportSchema.BookDTO(id: travelID, name: "Travel", icon: "airplane",
                                          type: 1, order: 1, archived: false,
                                          dateCreated: travelCreated)
        let category = ExportSchema.CategoryDTO(id: categoryID, name: "Transport",
                                                emoji: "✈️", colour: "#00FF00",
                                                income: false, order: 1,
                                                dateCreated: .now, bookID: travelID)
        let transaction = ExportSchema.TransactionDTO(
            id: UUID(), amount: 25, date: .now, day: nil, month: nil, note: "train",
            income: false, recurringType: 0, recurringCoefficient: 0, onceRecurring: false,
            categoryId: categoryID, categoryName: "Transport", accountId: nil, accountName: nil,
            baseAmount: 25, accountCurrency: nil, discount: nil, reimbursable: nil,
            reimbursedAt: nil, adjustment: false, bookID: travelID)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let file = try encoder.encode(fixture.payload(
            categories: [category], transactions: [transaction],
            books: [defaultBook, travel]))
        let decoded = try DataImporter.decode(file)
        #expect(decoded.books.count == 2)

        let summary = try DataImporter.apply(decoded, context: fixture.context)
        #expect(summary.books == 1)  // the default book already exists locally

        let books = try fixture.context.fetch(FetchDescriptor<BookModel>())
            .sorted { $0.order < $1.order }
        #expect(books.count == 2)
        #expect(books.first?.id == BookModel.defaultID)
        #expect(books.last?.id == travelID)
        #expect(books.last?.name == "Travel")
        #expect(books.last?.icon == "airplane")
        #expect(books.last?.type == 1)
        #expect(books.last?.dateCreated == travelCreated)
        #expect(books.last?.archived == false)

        let stored = try fixture.context.fetch(FetchDescriptor<TransactionModel>())
        #expect(stored.count == 1)
        #expect(stored.first?.bookID == travelID)
        let storedCategory = try #require(
            fixture.context.fetch(FetchDescriptor<CategoryModel>()).first)
        #expect(storedCategory.bookID == travelID)
    }

    @Test("A backup with no books still lands in the default book")
    func oldBackupUsesDefaultBook() throws {
        let legacyID = UUID().uuidString
        let json = """
        {
          "exportDate": "2026-01-02T03:04:05Z",
          "appVersion": "3.0",
          "schemaVersion": 8,
          "transactions": [
            {"id": "\(legacyID)", "amount": 10, "income": false,
             "recurringType": 0, "recurringCoefficient": 0, "onceRecurring": false}
          ],
          "categories": [], "accounts": []
        }
        """
        let payload = try DataImporter.decode(Data(json.utf8))
        #expect(payload.books.isEmpty)
        #expect(payload.transactions.first?.bookID == nil)

        _ = try DataImporter.apply(payload, context: fixture.context)
        let stored = try fixture.context.fetch(FetchDescriptor<TransactionModel>())
        #expect(stored.first?.bookID == BookModel.defaultID)
        let books = try fixture.context.fetch(FetchDescriptor<BookModel>())
        #expect(books.count == 1)
        #expect(books.first?.name == BookModel.defaultName)
    }
}
