//
//  DataImporter.swift
//  smartbud
//
//  Reads a JSON file written by `DataExporter` back into the local store.
//  This is the restore half of the portability promise: a new device, or a
//  store recovered from an erase, can be rebuilt from the export file.
//
//  ## Merge, never replace
//
//  Every entity that has an id is matched on it. Rows already present are
//  skipped, so importing the same file twice is a no-op and importing onto a
//  populated store cannot duplicate or clobber anything. Deleting data is
//  the job of Settings → Erase, not of an import.
//
//  ## Tolerant decoding
//
//  Older exports are missing whole sections (transfers and rates were added
//  in schema 4) and newer fields (discount, reimbursement, archive). Missing
//  sections decode as empty and missing fields as their defaults, so a 3.x
//  file still restores everything it knows about.
//

import Foundation
import SwiftData

@MainActor
enum DataImporter {

    /// What one import actually did, shown to the user when it finishes.
    struct Summary: Equatable {
        var categories = 0
        var accounts = 0
        var transactions = 0
        var transfers = 0
        var budgets = 0
        var mainBudgets = 0
        var templates = 0
        var rates = 0
        /// Rows already on this device (same id) that were left alone.
        var skipped = 0

        /// Records the user thinks of as "data". Rates are configuration and
        /// stay out of the count.
        var imported: Int {
            categories + accounts + transactions + transfers + budgets + mainBudgets + templates
        }

        var isEmpty: Bool { imported == 0 }
    }

    enum ImportError: LocalizedError {
        case unreadable
        case notABackup
        case writeFailed

        var errorDescription: String? {
            switch self {
            case .unreadable: String.appLocalized("This file could not be read.")
            case .notABackup: String.appLocalized("This file is not a SmartBud backup.")
            case .writeFailed: String.appLocalized("The backup could not be saved. Try again.")
            }
        }
    }

    // MARK: - Entry points

    /// Reads and applies the backup at `url`. The URL comes from a file
    /// importer, so it is security-scoped and must be unlocked explicitly.
    static func importFile(at url: URL, context: ModelContext) throws -> Summary {
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }

        guard let data = try? Data(contentsOf: url) else { throw ImportError.unreadable }
        return try apply(decode(data), context: context)
    }

    static func decode(_ data: Data) throws -> ExportSchema.Payload {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            let payload = try decoder.decode(ExportSchema.Payload.self, from: data)
            // `Payload` is lenient enough that any JSON object decodes to an
            // empty file. A real backup always carries a schema version, so
            // that is the one key we insist on.
            guard payload.exportedBySmartBud else { throw ImportError.notABackup }
            return payload
        } catch let error as ImportError {
            throw error
        } catch {
            throw ImportError.notABackup
        }
    }

    /// Merges `payload` into `context` in a single save. On failure the
    /// context is rolled back so a half-imported file leaves no trace.
    static func apply(
        _ payload: ExportSchema.Payload,
        context: ModelContext
    ) throws -> Summary {
        var merger = BackupMerger(context: context)

        merger.importCategories(payload.categories)
        merger.importAccounts(payload.accounts)
        merger.importRates(payload.rates)
        merger.importTransactions(payload.transactions)
        merger.importTransfers(payload.transfers)
        merger.importBudgets(payload.budgets)
        merger.importMainBudgets(payload.mainBudgets)
        merger.importTemplates(payload.templates)

        do {
            try context.save()
        } catch {
            context.rollback()
            throw ImportError.writeFailed
        }
        return merger.summary
    }
}

// MARK: - Merger

/// Holds the id lookups while one file is applied. A single instance per
/// import keeps the relationship resolution consistent: a transaction can
/// only point at a category this same run created or found.
private struct BackupMerger {
    let context: ModelContext
    var summary = DataImporter.Summary()

    var categoriesByID: [UUID: CategoryModel] = [:]
    var categoriesByName: [String: CategoryModel] = [:]
    var accountsByID: [UUID: AccountModel] = [:]
    var accountsByName: [String: AccountModel] = [:]

    init(context: ModelContext) {
        self.context = context
        for category in fetch(CategoryModel.self) {
            categoriesByID[category.id] = category
            categoriesByName[category.name] = category
        }
        for account in fetch(AccountModel.self) {
            accountsByID[account.id] = account
            accountsByName[account.name] = account
        }
    }

    // MARK: Categories and accounts

    mutating func importCategories(_ dtos: [ExportSchema.CategoryDTO]) {
        for dto in dtos {
            guard categoriesByID[dto.id] == nil else {
                summary.skipped += 1
                continue
            }
            let category = CategoryModel(
                name: dto.name, emoji: dto.emoji, colour: dto.colour,
                income: dto.income, order: dto.order
            )
            category.id = dto.id
            category.dateCreated = dto.dateCreated
            context.insert(category)
            categoriesByID[dto.id] = category
            categoriesByName[dto.name] = category
            summary.categories += 1
        }
    }

    mutating func importAccounts(_ dtos: [ExportSchema.AccountDTO]) {
        for dto in dtos {
            guard accountsByID[dto.id] == nil else {
                summary.skipped += 1
                continue
            }
            let account = AccountModel(
                name: dto.name, emoji: dto.emoji, colour: dto.colour,
                kind: dto.kind, currencyCode: dto.currencyCode,
                openingBalance: dto.openingBalance, order: dto.order
            )
            account.id = dto.id
            account.hidden = dto.hidden
            account.archived = dto.archived ?? false
            account.dateCreated = dto.dateCreated
            context.insert(account)
            accountsByID[dto.id] = account
            accountsByName[dto.name] = account
            summary.accounts += 1
        }
    }

    mutating func importRates(_ dtos: [ExportSchema.RateDTO]) {
        var byCode: [String: CurrencyRate] = [:]
        for rate in fetch(CurrencyRate.self) { byCode[rate.code] = rate }

        for dto in dtos where !dto.code.isEmpty {
            if let rate = byCode[dto.code] {
                rate.rate = dto.rate
                rate.updatedAt = dto.updatedAt
            } else {
                let rate = CurrencyRate(code: dto.code, rate: dto.rate)
                rate.updatedAt = dto.updatedAt
                context.insert(rate)
                byCode[dto.code] = rate
            }
            summary.rates += 1
        }
    }

    // MARK: Ledger

    mutating func importTransactions(_ dtos: [ExportSchema.TransactionDTO]) {
        var existing = Set(fetch(TransactionModel.self).map(\.id))

        for dto in dtos {
            guard existing.insert(dto.id).inserted else {
                summary.skipped += 1
                continue
            }
            let transaction = TransactionModel(
                note: dto.note ?? "",
                category: resolveCategory(id: dto.categoryId, name: dto.categoryName),
                account: resolveAccount(id: dto.accountId, name: dto.accountName),
                baseAmount: dto.baseAmount,
                income: dto.income,
                amount: dto.amount,
                date: dto.date ?? .now,
                repeatType: dto.recurringType,
                repeatCoefficient: dto.recurringCoefficient,
                discount: dto.discount ?? 0,
                reimbursable: dto.reimbursable ?? false,
                adjustment: dto.adjustment ?? false
            )
            transaction.id = dto.id
            transaction.onceRecurring = dto.onceRecurring
            transaction.reimbursedAt = dto.reimbursedAt
            if let day = dto.day { transaction.day = day }
            if let month = dto.month { transaction.month = month }
            context.insert(transaction)
            summary.transactions += 1
        }
    }

    mutating func importTransfers(_ dtos: [ExportSchema.TransferDTO]) {
        var existing = Set(fetch(TransferModel.self).map(\.id))

        for dto in dtos {
            guard existing.insert(dto.id).inserted else {
                summary.skipped += 1
                continue
            }
            // A transfer needs both ends to stay meaningful; an orphan
            // would show an empty row in the ledger.
            guard let source = resolveAccount(id: dto.sourceId, name: dto.sourceName),
                  let destination = resolveAccount(id: dto.destinationId, name: dto.destinationName)
            else {
                summary.skipped += 1
                continue
            }

            let transfer = TransferModel(
                amount: dto.amount,
                destinationAmount: dto.destinationAmount ?? 0,
                fee: dto.fee ?? 0,
                date: dto.date,
                note: dto.note,
                source: source,
                destination: destination
            )
            transfer.id = dto.id
            context.insert(transfer)
            summary.transfers += 1
        }
    }

    // MARK: Budgets and templates

    mutating func importBudgets(_ dtos: [ExportSchema.BudgetDTO]) {
        var existing = Set(fetch(BudgetModel.self).map(\.id))

        for dto in dtos {
            guard existing.insert(dto.id).inserted else {
                summary.skipped += 1
                continue
            }
            let budget = BudgetModel(amount: dto.amount, startDate: dto.startDate, type: dto.type)
            budget.id = dto.id
            budget.dateCreated = dto.dateCreated
            budget.green = dto.green
            budget.category = resolveCategory(id: dto.categoryId, name: dto.categoryName)
            context.insert(budget)
            summary.budgets += 1
        }
    }

    /// Main budgets carry no id, so dedupe on the values that identify one.
    mutating func importMainBudgets(_ dtos: [ExportSchema.MainBudgetDTO]) {
        var keys = Set(fetch(MainBudgetModel.self).map {
            key(amount: $0.amount, start: $0.startDate, type: $0.type)
        })

        for dto in dtos {
            guard keys.insert(key(amount: dto.amount, start: dto.startDate, type: dto.type)).inserted else {
                summary.skipped += 1
                continue
            }
            let mainBudget = MainBudgetModel(
                amount: dto.amount, startDate: dto.startDate, type: dto.type)
            mainBudget.dateCreated = dto.dateCreated
            mainBudget.green = dto.green
            context.insert(mainBudget)
            summary.mainBudgets += 1
        }
    }

    mutating func importTemplates(_ dtos: [ExportSchema.TemplateTransactionDTO]) {
        var existing = Set(fetch(TemplateTransactionModel.self).map(\.id))

        for dto in dtos {
            guard existing.insert(dto.id).inserted else {
                summary.skipped += 1
                continue
            }
            let template = TemplateTransactionModel(
                note: dto.note ?? "", category: resolveCategory(id: dto.categoryId, name: dto.categoryName),
                income: dto.income, amount: dto.amount, order: dto.order,
                repeatType: dto.recurringType, repeatCoefficient: dto.recurringCoefficient
            )
            template.id = dto.id
            context.insert(template)
            summary.templates += 1
        }
    }

    // MARK: Lookups

    private func resolveCategory(id: UUID?, name: String?) -> CategoryModel? {
        if let id, let match = categoriesByID[id] { return match }
        if let name, let match = categoriesByName[name] { return match }
        return nil
    }

    private func resolveAccount(id: UUID?, name: String?) -> AccountModel? {
        if let id, let match = accountsByID[id] { return match }
        if let name, let match = accountsByName[name] { return match }
        return nil
    }

    private func fetch<T: PersistentModel>(_ type: T.Type) -> [T] {
        (try? context.fetch(FetchDescriptor<T>())) ?? []
    }

    private func key(amount: Double, start: Date, type: Int) -> String {
        "\(Money.cents(amount))|\(Int(start.timeIntervalSince1970))|\(type)"
    }
}
