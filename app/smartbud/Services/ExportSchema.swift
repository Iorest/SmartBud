//
//  ExportSchema.swift
//  smartbud
//
//  Shape of the JSON export file, kept free of SwiftData and of the
//  repository so both the exporter and the importer (and their tests) can
//  share one definition. Field names here are the on-disk contract: renaming
//  one is a breaking change for previously saved backups.
//

import Foundation

enum ExportSchema {
    /// Bumped when the format changes in a way importers must distinguish.
    /// Old values are never reused.
    static let version: Int = 4

    struct Payload: Codable {
        var exportDate: Date
        var appVersion: String
        var schemaVersion: Int
        var transactions: [TransactionDTO]
        var categories: [CategoryDTO]
        var budgets: [BudgetDTO]
        var mainBudgets: [MainBudgetDTO]
        var templates: [TemplateTransactionDTO]
        var accounts: [AccountDTO]
        var transfers: [TransferDTO]
        var rates: [RateDTO]
        /// App settings that decide how the numbers are read. Optional so
        /// files written before this field still decode.
        var settings: SettingsDTO?

        init(
            exportDate: Date,
            appVersion: String,
            schemaVersion: Int,
            transactions: [TransactionDTO],
            categories: [CategoryDTO],
            budgets: [BudgetDTO],
            mainBudgets: [MainBudgetDTO],
            templates: [TemplateTransactionDTO],
            accounts: [AccountDTO],
            transfers: [TransferDTO],
            rates: [RateDTO],
            settings: SettingsDTO? = nil
        ) {
            self.exportDate = exportDate
            self.appVersion = appVersion
            self.schemaVersion = schemaVersion
            self.transactions = transactions
            self.categories = categories
            self.budgets = budgets
            self.mainBudgets = mainBudgets
            self.templates = templates
            self.accounts = accounts
            self.transfers = transfers
            self.rates = rates
            self.settings = settings
        }

        /// Lenient on purpose: a file written by an older build can be missing
        /// whole sections (transfers and rates arrived in schema 4), and the
        /// importer treats those as empty rather than rejecting the file.
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            exportDate = try container.decodeIfPresent(Date.self, forKey: .exportDate) ?? .now
            appVersion = try container.decodeIfPresent(String.self, forKey: .appVersion) ?? ""
            schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 0
            transactions = try container.decodeIfPresent([TransactionDTO].self, forKey: .transactions) ?? []
            categories = try container.decodeIfPresent([CategoryDTO].self, forKey: .categories) ?? []
            budgets = try container.decodeIfPresent([BudgetDTO].self, forKey: .budgets) ?? []
            mainBudgets = try container.decodeIfPresent([MainBudgetDTO].self, forKey: .mainBudgets) ?? []
            templates = try container.decodeIfPresent([TemplateTransactionDTO].self, forKey: .templates) ?? []
            accounts = try container.decodeIfPresent([AccountDTO].self, forKey: .accounts) ?? []
            transfers = try container.decodeIfPresent([TransferDTO].self, forKey: .transfers) ?? []
            rates = try container.decodeIfPresent([RateDTO].self, forKey: .rates) ?? []
            settings = try container.decodeIfPresent(SettingsDTO.self, forKey: .settings)
        }

        /// `true` when the file carries the marker every SmartBud export has.
        /// Decoding alone cannot tell a backup from any other JSON object
        /// because every field has a default.
        var exportedBySmartBud: Bool { schemaVersion > 0 }
    }

    /// Everything the importer needs to read the amounts the way they were
    /// written. Without `baseCurrency` a backup restored on a device using
    /// another base would be reinterpreted, not converted.
    struct SettingsDTO: Codable, Equatable {
        var baseCurrency: String?
        var firstDayOfMonth: Int?
        var firstWeekday: Int?
    }

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
        var accountId: UUID?
        var accountName: String?
        var baseAmount: Double?
        var accountCurrency: String?
        // Schema 4 additions. Optional so files written by 3.x still decode.
        var discount: Double?
        var reimbursable: Bool?
        var reimbursedAt: Date?
        var adjustment: Bool?
    }

    struct AccountDTO: Codable {
        var id: UUID
        var name: String
        var emoji: String
        var colour: String
        var kind: Int
        var openingBalance: Double
        var hidden: Bool
        var order: Int
        var dateCreated: Date
        var currencyCode: String
        // Schema 4. Optional so older files still decode.
        var archived: Bool?
    }

    struct RateDTO: Codable {
        var code: String
        var rate: Double
        var updatedAt: Date
    }

    struct TransferDTO: Codable {
        var id: UUID
        var amount: Double
        var date: Date
        var note: String?
        var sourceId: UUID?
        var sourceName: String?
        var destinationId: UUID?
        var destinationName: String?
        // Schema 4. Optional so older files still decode.
        var destinationAmount: Double?
        var fee: Double?
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
}
