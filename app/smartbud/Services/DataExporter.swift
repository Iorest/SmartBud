//
//  DataExporter.swift
//  smartbud
//
//  GDPR Article 20 — "Right to data portability". Serialises every
//  record in the local SwiftData store to a single JSON file in the
//  app's temp directory and returns its URL. The SettingsExportView
//  then hands that URL to a `UIActivityViewController` share sheet
//  so the user can save the file to Files, AirDrop it, mail it to
//  themselves, etc.
//
//  The format is intentionally plain JSON (not Codable on the
//  SwiftData @Model types) so the export stays stable across schema
//  changes — adding a new field to `TransactionModel` doesn't break
//  older exports. The schema version lives in `schemaVersion` and
//  can be bumped if a future migration needs to be detected.
//
//  CloudKit-synced data: this export is local-only. It covers the
//  records the user has on this device, which under normal
//  circumstances is the same set every other device has via iCloud
//  sync. If the device is offline and has never synced, this is
//  the only data SmartBud has for the user.
//

import Foundation
import SwiftData

@MainActor
enum DataExporter {
    /// Bumped manually if the export format changes in a way that
    /// importers need to distinguish (e.g. moving a category into a
    /// nested structure). Old values are never reused.
    static let schemaVersion: Int = 1

    enum ExportError: Error, LocalizedError {
        case noData
        case writeFailed(Error)

        var errorDescription: String? {
            switch self {
            case .noData: String.appLocalized(SettingsKey.exportEmpty)
            case .writeFailed(let error): error.localizedDescription
            }
        }
    }

    /// Top-level export shape. The Codable conformance serialises to
    /// the format documented in the file header.
    struct ExportPayload: Codable {
        var exportDate: Date
        var appVersion: String
        var schemaVersion: Int
        var transactions: [TransactionDTO]
        var categories: [CategoryDTO]
        var budgets: [BudgetDTO]
        var mainBudgets: [MainBudgetDTO]
        var templates: [TemplateTransactionDTO]
    }

    // MARK: - DTOs (decoupled from @Model so the export format is stable)

    struct TransactionDTO: Codable {
        var id: UUID
        var amount: Double
        var date: Date?
        var day: Date?
        var month: Date?
        var note: String?
        var income: Bool
        var recurringType: Int
        var recurringCoefficient: Int
        var onceRecurring: Bool
        var categoryId: UUID?
        var categoryName: String?
    }

    struct CategoryDTO: Codable {
        var id: UUID
        var name: String
        var emoji: String
        var colour: String
        var income: Bool
        var order: Int
        var dateCreated: Date
    }

    struct BudgetDTO: Codable {
        var id: UUID
        var amount: Double
        var startDate: Date
        var dateCreated: Date
        var type: Int
        var green: Bool
        var categoryId: UUID?
        var categoryName: String?
    }

    struct MainBudgetDTO: Codable {
        var amount: Double
        var startDate: Date
        var dateCreated: Date
        var type: Int
        var green: Bool
    }

    struct TemplateTransactionDTO: Codable {
        var id: UUID
        var amount: Double
        var note: String?
        var income: Bool
        var order: Int
        var recurringType: Int
        var recurringCoefficient: Int
        var categoryId: UUID?
        var categoryName: String?
    }

    // MARK: - Entry point

    /// Generates the export, writes it to the temp directory, and
    /// returns the file URL. Throws `ExportError.noData` if the user
    /// hasn't created anything yet.
    static func exportToFile(repo: DataRepository = .shared) throws -> URL {
        let payload = try makePayload(repo: repo)

        if payload.transactions.isEmpty,
           payload.categories.isEmpty,
           payload.budgets.isEmpty,
           payload.mainBudgets.isEmpty,
           payload.templates.isEmpty {
            throw ExportError.noData
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let data: Data
        do {
            data = try encoder.encode(payload)
        } catch {
            throw ExportError.writeFailed(error)
        }

        let filename = makeFilename(exportDate: payload.exportDate)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        do {
            try data.write(to: url, options: .atomic)
        } catch {
            throw ExportError.writeFailed(error)
        }
        return url
    }

    // MARK: - Payload assembly

    private static func categoriesDTOs(_ repo: DataRepository) -> [CategoryDTO] {
    repo.fetch(CategoryModel.self)
        .sorted { $0.order < $1.order }
        .map { cat in
            CategoryDTO(
                id: cat.id, name: cat.name, emoji: cat.emoji, colour: cat.colour,
                income: cat.income, order: cat.order, dateCreated: cat.dateCreated
            )
        }

    }

    private static func transactionsDTOs(_ repo: DataRepository) -> [TransactionDTO] {
    repo.fetch(TransactionModel.self)
        .sorted { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
        .map { txn in
            TransactionDTO(
                id: txn.id,
                amount: txn.amount,
                date: txn.date,
                day: txn.day,
                month: txn.month,
                note: txn.note,
                income: txn.income,
                recurringType: txn.recurringType,
                recurringCoefficient: txn.recurringCoefficient,
                onceRecurring: txn.onceRecurring,
                categoryId: txn.category?.id,
                categoryName: txn.category?.name
            )
        }

    }

    private static func budgetsDTOs(_ repo: DataRepository) -> [BudgetDTO] {
    repo.fetch(BudgetModel.self)
        .sorted { $0.startDate < $1.startDate }
        .map { budget in
            BudgetDTO(
                id: budget.id, amount: budget.amount, startDate: budget.startDate,
                dateCreated: budget.dateCreated, type: budget.type, green: budget.green,
                categoryId: budget.category?.id, categoryName: budget.category?.name
            )
        }

    }

    private static func mainBudgetsDTOs(_ repo: DataRepository) -> [MainBudgetDTO] {
    repo.fetch(MainBudgetModel.self)
        .sorted { $0.startDate < $1.startDate }
        .map { mainBudget in
            MainBudgetDTO(
                amount: mainBudget.amount, startDate: mainBudget.startDate,
                dateCreated: mainBudget.dateCreated, type: mainBudget.type, green: mainBudget.green
            )
        }

    }

    private static func templatesDTOs(_ repo: DataRepository) -> [TemplateTransactionDTO] {
    repo.fetch(TemplateTransactionModel.self)
        .sorted { $0.order < $1.order }
        .map { template in
            TemplateTransactionDTO(
                id: template.id, amount: template.amount, note: template.note,
                income: template.income, order: template.order,
                recurringType: template.recurringType,
                recurringCoefficient: template.recurringCoefficient,
                categoryId: template.category?.id, categoryName: template.category?.name
            )
        }

    }

    private static func makePayload(repo: DataRepository) throws -> ExportPayload {
        let appVersion = Bundle.main.appVersion
        let exportDate = Date.now

        let categories = categoriesDTOs(repo)

        let transactions = transactionsDTOs(repo)

        let budgets = budgetsDTOs(repo)

        let mainBudgets = mainBudgetsDTOs(repo)

        let templates = templatesDTOs(repo)

        return ExportPayload(
            exportDate: exportDate,
            appVersion: appVersion,
            schemaVersion: schemaVersion,
            transactions: transactions,
            categories: categories,
            budgets: budgets,
            mainBudgets: mainBudgets,
            templates: templates
        )
    }

    private static func makeFilename(exportDate: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return "smartbud-export-\(formatter.string(from: exportDate)).json"
    }
}
