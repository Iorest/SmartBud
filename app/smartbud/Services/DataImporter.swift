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
        /// Ledgers restored from the file. The structural default book is
        /// not counted here — it is created locally, not imported.
        var books = 0
        /// Rows already on this device (same id) that were left alone.
        var skipped = 0
        /// Settings from the backup that still have to be written to the app
        /// (only when this device had no data to protect).
        var settingsToApply: ExportSchema.SettingsDTO?

        /// Records the user thinks of as "data". Rates are configuration and
        /// stay out of the count.
        var imported: Int {
            categories + accounts + transactions + transfers + budgets + mainBudgets + templates + books
        }

        var isEmpty: Bool { imported == 0 }
    }

    enum ImportError: LocalizedError {
        case unreadable
        case notABackup
        case newerVersion
        case baseCurrencyMismatch(backup: String, local: String)
        case writeFailed

        var errorDescription: String? {
            switch self {
            case .unreadable: String.appLocalized("This file could not be read.")
            case .notABackup: String.appLocalized("This file is not a SmartBud backup.")
            case .newerVersion:
                String.appLocalized("This backup comes from a newer version of SmartBud. "
                                    + "Update the app before restoring it.")
            case .baseCurrencyMismatch(let backup, let local):
                String.appFormatted(
                    "This backup was recorded in %@ but this device uses %@. "
                        + "Switch the base currency first, or erase the data and import again.",
                    backup, local)
            case .writeFailed: String.appLocalized("The backup could not be saved. Try again.")
            }
        }
    }

    // MARK: - Entry points

    /// Reads and applies the backup at `url`. The URL comes from a file
    /// importer, so it is security-scoped and must be unlocked explicitly.
    static func importFile(at url: URL, context: ModelContext) throws -> Summary {
        try apply(decodeFile(at: url), context: context)
    }

    /// Reads and validates the file without writing anything, so the UI can
    /// show "N records" before the user commits.
    static func decodeFile(at url: URL) throws -> ExportSchema.Payload {
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }

        guard let data = try? Data(contentsOf: url) else { throw ImportError.unreadable }
        return try decode(data)
    }

    /// What the file contains, counted without touching the store. Skips are
    /// not predicted — that depends on what is already here.
    static func preview(_ payload: ExportSchema.Payload) -> Summary {
        var summary = Summary()
        summary.categories = payload.categories.count
        summary.accounts = payload.accounts.count
        summary.transactions = payload.transactions.count
        summary.transfers = payload.transfers.count
        summary.budgets = payload.budgets.count
        summary.mainBudgets = payload.mainBudgets.count
        summary.templates = payload.templates.count
        summary.rates = payload.rates.count
        summary.books = payload.books.count
        return summary
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
            // A future format may store amounts or relationships differently;
            // importing it silently would write wrong numbers into the ledger.
            guard payload.schemaVersion <= ExportSchema.version else {
                throw ImportError.newerVersion
            }
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
        let settingsToApply = try resolveSettings(payload, context: context)
        // A restore can run before the first bootstrap. Create the structural
        // default book inside this same save/rollback boundary.
        BookMigration.ensureDefaultBook(in: context)
        var merger = BackupMerger(context: context)
        merger.importBooks(payload.books)

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

        var summary = merger.summary
        summary.settingsToApply = settingsToApply
        return summary
    }

    /// A backup carries the base currency its amounts were frozen in. Restoring
    /// it onto a device that already has data in another currency would
    /// reinterpret every total, so that combination is refused; an empty device
    /// simply adopts the backup's settings.
    private static func resolveSettings(
        _ payload: ExportSchema.Payload,
        context: ModelContext
    ) throws -> ExportSchema.SettingsDTO? {
        guard let settings = payload.settings,
              let backupBase = settings.baseCurrency?.uppercased(),
              !backupBase.isEmpty else { return nil }

        let storeIsEmpty = isEmpty(context)
        let localBase = AppBaseCurrency.code.uppercased()

        if storeIsEmpty { return settings }
        if !localBase.isEmpty, localBase != backupBase {
            throw ImportError.baseCurrencyMismatch(backup: backupBase, local: localBase)
        }
        // Same currency: keep the user's own period settings.
        return nil
    }

    private static func isEmpty(_ context: ModelContext) -> Bool {
        func count<T: PersistentModel>(_ type: T.Type) -> Int {
            (try? context.fetchCount(FetchDescriptor<T>())) ?? 0
        }
        return count(TransactionModel.self) == 0
            && count(CategoryModel.self) == 0
            && count(AccountModel.self) == 0
            && count(BudgetModel.self) == 0
            && count(MainBudgetModel.self) == 0
            && count(TemplateTransactionModel.self) == 0
    }
}
