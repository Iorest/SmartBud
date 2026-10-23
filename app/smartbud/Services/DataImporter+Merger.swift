//
//  DataImporter+Merger.swift
//  smartbud
//
//  The row-by-row half of the import: resolves relationships, skips records
//  that are already here, and validates values. Split from DataImporter.swift
//  so each file stays focused (and within the length limit).
//

import Foundation
import SwiftData

// MARK: - Merger

/// Holds the id lookups while one file is applied. A single instance per
/// import keeps the relationship resolution consistent: a transaction can
/// only point at a category this same run created or found.
struct BackupMerger {
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
                openingBalance: signedAmount(dto.openingBalance), order: dto.order
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
            guard dto.rate.isFinite, dto.rate > 0 else {
                summary.skipped += 1
                continue
            }
            if let rate = byCode[dto.code] {
                rate.rate = min(dto.rate, 1_000_000)
                rate.updatedAt = dto.updatedAt
            } else {
                let rate = CurrencyRate(code: dto.code, rate: min(dto.rate, 1_000_000))
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
                baseAmount: dto.baseAmount.map(amount),
                income: dto.income,
                amount: amount(dto.amount),
                date: dto.date ?? .now,
                repeatType: dto.recurringType,
                repeatCoefficient: dto.recurringCoefficient,
                discount: amount(dto.discount ?? 0),
                reimbursable: dto.reimbursable ?? false,
                reimbursementOf: dto.reimbursementOf,
                transferFeeOf: dto.transferFeeOf,
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
                amount: amount(dto.amount),
                destinationAmount: amount(dto.destinationAmount ?? 0),
                fee: amount(dto.fee ?? 0),
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
            let budget = BudgetModel(amount: amount(dto.amount),
                                     startDate: dto.startDate, type: dto.type)
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
                amount: amount(dto.amount), startDate: dto.startDate, type: dto.type)
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
                income: dto.income, amount: amount(dto.amount), order: dto.order,
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

    // MARK: Validation

    /// Amounts are magnitudes (expenses store `income` separately), so a
    /// negative or absurd value from a hand-edited file becomes 0/ceiling
    /// instead of poisoning every total derived from it.
    private func amount(_ value: Double) -> Double {
        guard value.isFinite else { return 0 }
        return min(max(value, 0), Money.maxAmount)
    }

    /// Opening balances can be negative (credit cards) but not infinite.
    private func signedAmount(_ value: Double) -> Double {
        guard value.isFinite else { return 0 }
        return min(max(value, -Money.maxAmount), Money.maxAmount)
    }
}
