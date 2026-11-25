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
    /// Old values are never reused. Schema 10 adds `installmentPlans` and the
    /// three `installment*` fields on a transaction; v9 files have none of
    /// them and still decode with an empty plan list. Number allocated by the
    /// coordinator — do not take one here.
    static let version: Int = 10

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
        /// Ledgers in the backup. Empty in files written before multi-ledger
        /// support; their rows decode with a nil `bookID` and land in the
        /// default book.
        var books: [BookDTO]
        /// Installment plans and their generated bills. Additive: a backup
        /// written before this section simply decodes with no plans, so no
        /// schema version bump or data migration is needed.
        var installmentPlans: [InstallmentPlanDTO]
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
            settings: SettingsDTO? = nil,
            books: [BookDTO] = [],
            installmentPlans: [InstallmentPlanDTO] = []
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
            self.books = books
            self.installmentPlans = installmentPlans
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
            books = try container.decodeIfPresent([BookDTO].self, forKey: .books) ?? []
            installmentPlans = try container.decodeIfPresent([InstallmentPlanDTO].self, forKey: .installmentPlans) ?? []
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

        /// What the current device writes into a backup. `baseCurrency` must
        /// never be empty: without it a restore cannot tell whether the frozen
        /// amounts are in its own currency. A fresh install has no stored
        /// choice, so it falls back to the same rule the app uses everywhere.
        static func current(defaults: UserDefaults = .appGroup) -> SettingsDTO {
            SettingsDTO(
                baseCurrency: AppBaseCurrency.code(in: defaults),
                firstDayOfMonth: defaults.object(forKey: "firstDayOfMonth") as? Int,
                firstWeekday: defaults.object(forKey: "firstWeekday") as? Int
            )
        }
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
        /// On a claim: the total already paid back, in the base currency
        /// (schema 9). Optional so older backups still decode; a full
        /// settlement in those files is recognised by `reimbursedAt`.
        var reimbursedAmount: Double? = nil
        /// On the income row that settles a claim: the id of the expense.
        var reimbursementOf: UUID?
        /// On a refund row (schema 7): the id of the expense it gives back.
        /// Optional so files written before 7 still decode — their refunds, if
        /// any, were recorded as plain income and stay that way.
        var refundOf: UUID?
        /// On the expense row that pays a transfer's fee: the id of the transfer.
        var transferFeeOf: UUID?
        var adjustment: Bool?
        /// On the expense row that writes off a claim (schema 8): the id of the
        /// claim. Optional so files written before 8 still decode — their
        /// unwritten-off claims simply stay claims.
        var badDebtOf: UUID?
        /// Why the claim was written off (`BadDebtPolicy.Reason` raw value).
        var badDebtReason: String?
        /// On a written-off claim: the day the money was given up on.
        var badDebtAt: Date?
        /// Ledger this row belongs to. Nil in pre-book backups.
        var bookID: UUID? = nil
        /// On an installment bill: the plan that generated it. Optional so
        /// older backups (and ordinary rows) still decode.
        var installmentOf: UUID? = nil
        /// 1-based period of a generated bill.
        var installmentPeriod: Int? = nil
        /// 1 = fee/interest, 2 = principal. Nil on ordinary rows.
        var installmentKind: Int? = nil
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
        /// Ledger this account belongs to. Nil in pre-book backups.
        var bookID: UUID? = nil
        /// Credit-only terms. Optional: older backups and non-card accounts
        /// leave them nil; the coordinator assigns the next schema number
        /// when these fields ship.
        var creditLimit: Double? = nil
        var statementDay: Int? = nil
        var dueDay: Int? = nil
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
        /// Ledger this category belongs to. Nil in pre-book backups.
        var bookID: UUID? = nil
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
        /// Ledger this budget belongs to. Nil in pre-book backups.
        var bookID: UUID? = nil
    }

    struct MainBudgetDTO: Codable {
        var amount: Double
        var startDate: Date
        var dateCreated: Date
        var type: Int
        var green: Bool
        /// Ledger this budget belongs to. Nil in pre-book backups.
        var bookID: UUID? = nil
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
        /// Ledger this template belongs to. Nil in pre-book backups.
        var bookID: UUID? = nil
    }

    /// One ledger. Unknown fields in a newer file are ignored by Codable, so
    /// restoring a multi-ledger backup into an older build drops the extra
    /// books — the coordinator-assigned version bump must land with the UI
    /// release that exposes more than one book.
    struct BookDTO: Codable {
        var id: UUID
        var name: String
        var icon: String
        var type: Int
        var order: Int
        var archived: Bool
        /// Optional so backups written before books existed still decode.
        var dateCreated: Date?
    }

    /// One installment plan. Amounts are base-currency; the generated rows
    /// carry their own frozen base amount, so restoring keeps both sides.
    struct InstallmentPlanDTO: Codable {
        var id: UUID
        var bookID: UUID? = nil
        var principal: Double
        var fee: Double
        var periods: Int
        var firstDate: Date
        var executedPeriods: Int
        var accountId: UUID?
        var accountName: String?
        var categoryId: UUID?
        var categoryName: String?
        var note: String?
        var dateCreated: Date?
    }
}
