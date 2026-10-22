//
//  DataPortabilityTests.swift
//  SmartBudTests
//
//  The export format is the restore path: a file this app writes has to come
//  back in. These tests cover the merge rules of `DataImporter` against an
//  in-memory store plus the CSV escaping used by the spreadsheet export.
//

import Testing
import Foundation
import SwiftData

@MainActor
@Suite("DataImporter")
struct DataImporterTests {

    /// One in-memory store per test, held for the whole test so the
    /// container outlives the context (a released container invalidates it).
    private let container: ModelContainer
    private var context: ModelContext { container.mainContext }

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

    private func payload(
        categories: [ExportSchema.CategoryDTO] = [],
        accounts: [ExportSchema.AccountDTO] = [],
        transactions: [ExportSchema.TransactionDTO] = [],
        transfers: [ExportSchema.TransferDTO] = [],
        budgets: [ExportSchema.BudgetDTO] = [],
        mainBudgets: [ExportSchema.MainBudgetDTO] = [],
        templates: [ExportSchema.TemplateTransactionDTO] = [],
        rates: [ExportSchema.RateDTO] = []
    ) -> ExportSchema.Payload {
        ExportSchema.Payload(
            exportDate: .now, appVersion: "test", schemaVersion: ExportSchema.version,
            transactions: transactions, categories: categories, budgets: budgets,
            mainBudgets: mainBudgets, templates: templates, accounts: accounts,
            transfers: transfers, rates: rates
        )
    }

    private let categoryID = UUID()
    private let accountID = UUID()

    private var sampleCategory: ExportSchema.CategoryDTO {
        .init(id: categoryID, name: "餐饮", emoji: "🍜", colour: "#FF0000",
              income: false, order: 0, dateCreated: .now)
    }

    private var sampleAccount: ExportSchema.AccountDTO {
        .init(id: accountID, name: "招行", emoji: "💳", colour: "#279AF4", kind: 1,
              openingBalance: 1000, hidden: false, order: 0, dateCreated: .now,
              currencyCode: "CNY", archived: false)
    }

    @Test("Transactions resolve their category and account by id")
    func resolvesRelationshipsByID() throws {
        let context = context
        let transaction = ExportSchema.TransactionDTO(
            id: UUID(), amount: 32.5, date: .now, day: nil, month: nil,
            note: "午饭", income: false, recurringType: 0, recurringCoefficient: 0,
            onceRecurring: false, categoryId: categoryID, categoryName: "餐饮",
            accountId: accountID, accountName: "招行", baseAmount: 32.5,
            accountCurrency: "CNY", discount: 5, reimbursable: true,
            reimbursedAt: nil, adjustment: false
        )

        let summary = try DataImporter.apply(
            payload(categories: [sampleCategory], accounts: [sampleAccount],
                    transactions: [transaction]),
            context: context
        )

        #expect(summary.categories == 1)
        #expect(summary.accounts == 1)
        #expect(summary.transactions == 1)

        let stored = try context.fetch(FetchDescriptor<TransactionModel>())
        #expect(stored.count == 1)
        #expect(stored.first?.category?.id == categoryID)
        #expect(stored.first?.account?.id == accountID)
        #expect(stored.first?.discount == 5)
        #expect(stored.first?.reimbursable == true)
        #expect(stored.first?.isPendingReimbursement == true)
    }

    @Test("A missing category id falls back to the stored name")
    func fallsBackToCategoryName() throws {
        let context = context
        let transaction = ExportSchema.TransactionDTO(
            id: UUID(), amount: 10, date: .now, day: nil, month: nil,
            note: "", income: false, recurringType: 0, recurringCoefficient: 0,
            onceRecurring: false, categoryId: UUID(), categoryName: "餐饮",
            accountId: nil, accountName: nil, baseAmount: nil,
            accountCurrency: nil, discount: nil, reimbursable: nil,
            reimbursedAt: nil, adjustment: nil
        )

        _ = try DataImporter.apply(
            payload(categories: [sampleCategory], transactions: [transaction]),
            context: context
        )

        let stored = try context.fetch(FetchDescriptor<TransactionModel>())
        #expect(stored.first?.category?.name == "餐饮")
    }

    @Test("Importing the same file twice changes nothing")
    func isIdempotent() throws {
        let context = context
        let transaction = ExportSchema.TransactionDTO(
            id: UUID(), amount: 10, date: .now, day: nil, month: nil,
            note: "coffee", income: false, recurringType: 0, recurringCoefficient: 0,
            onceRecurring: false, categoryId: categoryID, categoryName: "餐饮",
            accountId: accountID, accountName: "招行", baseAmount: 10,
            accountCurrency: "CNY", discount: nil, reimbursable: nil,
            reimbursedAt: nil, adjustment: nil
        )
        let file = payload(categories: [sampleCategory], accounts: [sampleAccount],
                           transactions: [transaction])

        let first = try DataImporter.apply(file, context: context)
        let second = try DataImporter.apply(file, context: context)

        #expect(first.imported == 3)
        #expect(second.imported == 0)
        #expect(second.skipped == 3)

        let stored = try context.fetch(FetchDescriptor<TransactionModel>())
        #expect(stored.count == 1)
    }

    @Test("A transfer with an unknown account is skipped, not orphaned")
    func skipsOrphanTransfer() throws {
        let context = context
        let transfer = ExportSchema.TransferDTO(
            id: UUID(), amount: 50, date: .now, note: nil,
            sourceId: accountID, sourceName: "招行",
            destinationId: UUID(), destinationName: "不存在的账户",
            destinationAmount: nil, fee: nil
        )

        let summary = try DataImporter.apply(
            payload(accounts: [sampleAccount], transfers: [transfer]),
            context: context
        )

        #expect(summary.transfers == 0)
        #expect(summary.skipped == 1)
        #expect(try context.fetch(FetchDescriptor<TransferModel>()).isEmpty)
    }

    @Test("Transfer fee and received amount survive the round trip")
    func keepsTransferFee() throws {
        let context = context
        let second = ExportSchema.AccountDTO(
            id: UUID(), name: "美元账户", emoji: "💵", colour: "#00AA00", kind: 1,
            openingBalance: 0, hidden: false, order: 1, dateCreated: .now,
            currencyCode: "USD", archived: false
        )
        let transfer = ExportSchema.TransferDTO(
            id: UUID(), amount: 100, date: .now, note: "汇款",
            sourceId: accountID, sourceName: "招行",
            destinationId: second.id, destinationName: "美元账户",
            destinationAmount: 13.75, fee: 2.5
        )

        _ = try DataImporter.apply(
            payload(accounts: [sampleAccount, second], transfers: [transfer]),
            context: context
        )

        let stored = try context.fetch(FetchDescriptor<TransferModel>()).first
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
            payload(transactions: [transaction], rates: [badRate]),
            context: context
        )

        let stored = try context.fetch(FetchDescriptor<TransactionModel>()).first
        #expect(stored?.amount == 0)
        #expect(stored?.baseAmount == 0)
        #expect(stored?.discount == Money.maxAmount)
        #expect(try context.fetch(FetchDescriptor<CurrencyRate>()).isEmpty)
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
        context.insert(category)
        let account = AccountModel(name: "招行", currencyCode: "CNY", openingBalance: 100)
        context.insert(account)

        let original = TransactionModel(
            note: "午餐", category: category, account: account, baseAmount: 42.5,
            income: false, amount: 42.5, date: .now,
            discount: 5, reimbursable: true, adjustment: false
        )
        original.reimbursedAt = Date(timeIntervalSince1970: 1_700_000_000)
        context.insert(original)

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
        let context = context
        let archived = ExportSchema.AccountDTO(
            id: UUID(), name: "旧卡", emoji: "💳", colour: "#999999", kind: 1,
            openingBalance: 0, hidden: false, order: 2, dateCreated: .now,
            currencyCode: "CNY", archived: true
        )

        _ = try DataImporter.apply(payload(accounts: [archived]), context: context)

        let stored = try context.fetch(FetchDescriptor<AccountModel>())
        #expect(stored.first?.archived == true)
    }
}

@Suite("CSV escaping")
struct CSVSupportTests {

    @Test("Plain values are not quoted")
    func plainValue() {
        #expect(CSVSupport.field("lunch") == "lunch")
    }

    @Test("Commas force quoting")
    func comma() {
        #expect(CSVSupport.field("lunch, coffee") == "\"lunch, coffee\"")
    }

    @Test("Quotes are doubled")
    func quote() {
        #expect(CSVSupport.field("say \"hi\"") == "\"say \"\"hi\"\"\"")
    }

    @Test("Newlines force quoting")
    func newline() {
        #expect(CSVSupport.field("a\nb") == "\"a\nb\"")
    }

    @Test("Rows join escaped fields")
    func row() {
        #expect(CSVSupport.row(["a", "b,c", "d"]) == "a,\"b,c\",d")
    }
}

@Suite("Transaction classification")
struct TransactionClassificationTests {

    private func expense(_ amount: Double) -> TransactionModel {
        TransactionModel(amount: amount, date: .now)
    }

    @Test("A plain expense counts as spend")
    func plainExpense() {
        let txn = expense(20)
        #expect(txn.countsAsSpend)
        #expect(txn.signedBaseAmount == -20)
    }

    @Test("A reimbursable claim stays out of spend and of net")
    func reimbursableIsPassThrough() {
        let txn = expense(20)
        txn.reimbursable = true
        #expect(!txn.countsAsSpend)
        #expect(txn.signedBaseAmount == 0)
        #expect(txn.isPendingReimbursement)
    }

    @Test("Settling a claim still keeps it out of spend")
    func settledClaim() {
        let txn = expense(20)
        txn.reimbursable = true
        txn.reimbursedAt = .now
        #expect(!txn.isPendingReimbursement)
        #expect(!txn.countsAsSpend)
    }

    @Test("A balance adjustment is neither income nor spend")
    func adjustmentIsInvisibleToStats() {
        let txn = expense(50)
        txn.adjustment = true
        #expect(!txn.countsAsSpend)
        #expect(!txn.countsAsIncome)
        #expect(txn.signedBaseAmount == 0)
    }

    @Test("Income counts as income")
    func income() {
        let txn = expense(50)
        txn.income = true
        #expect(txn.countsAsIncome)
        #expect(txn.signedBaseAmount == 50)
    }

    @Test("A transfer fee is charged on top of the amount")
    func transferFee() {
        let transfer = TransferModel(amount: 100, destinationAmount: 0, fee: 2.5)
        #expect(transfer.outgoingTotal == 102.5)
        #expect(transfer.receivedAmount == 100)
    }

    @Test("A non-finite fee cannot inflate the outgoing total")
    func nonFiniteFee() {
        let transfer = TransferModel(amount: 100)
        transfer.fee = .nan
        #expect(transfer.outgoingTotal == 100)
    }

    @Test("Gross amount restores the pre-discount price")
    func grossAmount() {
        let txn = TransactionModel(amount: 80, date: .now, discount: 20)
        #expect(txn.grossAmount == 100)
    }
}
