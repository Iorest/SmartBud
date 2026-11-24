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
    var booksByID: [UUID: BookModel] = [:]
    var installmentPlansByID: [UUID: InstallmentPlanModel] = [:]

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
        for book in fetch(BookModel.self) { booksByID[book.id] = book }
    }

    mutating func importBooks(_ dtos: [ExportSchema.BookDTO]) {
        for dto in dtos {
            guard booksByID[dto.id] == nil else {
                summary.skipped += 1
                continue
            }
            let book = BookModel(name: dto.name, icon: dto.icon, type: dto.type,
                                 order: dto.order, archived: dto.archived)
            book.id = dto.id
            book.dateCreated = dto.dateCreated ?? .now
            context.insert(book)
            booksByID[dto.id] = book
            summary.books += 1
        }
    }

    /// Plans are restored after categories and accounts so their relationships
    /// resolve. Generated bills are ordinary rows carrying `installmentOf`, so
    /// the plan-to-bill relation survives a round trip without a second store.
    mutating func importInstallmentPlans(_ dtos: [ExportSchema.InstallmentPlanDTO]) {
        var existing = Set(fetch(InstallmentPlanModel.self).map(\.id))
        for dto in dtos {
            guard existing.insert(dto.id).inserted else {
                summary.skipped += 1
                continue
            }
            let plan = InstallmentPlanModel(
                principal: amount(dto.principal),
                fee: amount(dto.fee),
                periods: max(0, dto.periods),
                firstDate: dto.firstDate,
                note: dto.note,
                account: resolveAccount(id: dto.accountId, name: dto.accountName),
                category: resolveCategory(id: dto.categoryId, name: dto.categoryName),
                bookID: resolveBook(dto.bookID)
            )
            plan.id = dto.id
            plan.executedPeriods = max(0, min(dto.executedPeriods, plan.periods))
            if let created = dto.dateCreated { plan.dateCreated = created }
            context.insert(plan)
            installmentPlansByID[dto.id] = plan
            summary.installmentPlans += 1
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
                income: dto.income, order: dto.order,
                bookID: resolveBook(dto.bookID)
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
            account.bookID = resolveBook(dto.bookID)
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
            if byCode[dto.code] != nil {
                // Merge, never replace: the same rule the ledger rows follow.
                // Overwriting today's rates with an old backup's silently
                // changed every account balance and transfer suggestion.
                summary.skipped += 1
                continue
            }
            let rate = CurrencyRate(code: dto.code, rate: min(dto.rate, 1_000_000))
            rate.updatedAt = dto.updatedAt
            context.insert(rate)
            byCode[dto.code] = rate
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
                refundOf: dto.refundOf,
                badDebtOf: dto.badDebtOf,
                badDebtReason: dto.badDebtReason,
                transferFeeOf: dto.transferFeeOf,
                installmentOf: dto.installmentOf,
                installmentPeriod: dto.installmentPeriod ?? 0,
                installmentKind: dto.installmentKind ?? 0,
                adjustment: dto.adjustment ?? false
            )
            transaction.bookID = resolveBook(dto.bookID)
            transaction.id = dto.id
            transaction.onceRecurring = dto.onceRecurring
            // A backup written before schema 9 has no paid-back amount. A
            // settlement date from those files means the whole claim came
            // back; deriving it here keeps old statistics unchanged.
            transaction.reimbursedAmount = ReimbursementPolicy.clamped(
                reimbursed: dto.reimbursedAmount ?? (dto.reimbursedAt == nil ? 0
                                                                             : transaction.wrappedBaseAmount),
                baseAmount: transaction.wrappedBaseAmount)
            transaction.reimbursedAt = dto.reimbursedAt
            transaction.badDebtAt = dto.badDebtAt
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
            budget.bookID = resolveBook(dto.bookID)
            context.insert(budget)
            summary.budgets += 1
        }
    }

    /// Main budgets carry no id, so dedupe on the values that identify one.
    mutating func importMainBudgets(_ dtos: [ExportSchema.MainBudgetDTO]) {
        var keys = Set(fetch(MainBudgetModel.self).map {
            key(amount: $0.amount, start: $0.startDate, type: $0.type, bookID: $0.bookID)
        })

        for dto in dtos {
            let bookID = resolveBook(dto.bookID)
            guard keys.insert(key(amount: dto.amount, start: dto.startDate, type: dto.type,
                                   bookID: bookID)).inserted else {
                summary.skipped += 1
                continue
            }
            let mainBudget = MainBudgetModel(
                amount: amount(dto.amount), startDate: dto.startDate, type: dto.type)
            mainBudget.dateCreated = dto.dateCreated
            mainBudget.green = dto.green
            mainBudget.bookID = bookID
            context.insert(mainBudget)
            summary.mainBudgets += 1
        }
    }

    private func key(amount: Double, start: Date, type: Int, bookID: UUID?) -> String {
        "\(Money.cents(amount))|\(Int(start.timeIntervalSince1970))|\(type)|\(bookID?.uuidString ?? "")"
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
            template.bookID = resolveBook(dto.bookID)
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

    /// An unknown book id in a hand-edited backup must not create orphan
    /// rows: they fall into the default book, which always exists after
    /// `BookMigration.ensureDefaultBook`.
    private func resolveBook(_ id: UUID?) -> UUID? {
        let candidate = id ?? BookModel.defaultID
        guard candidate != BookModel.defaultID, booksByID[candidate] == nil else {
            return candidate
        }
        return BookModel.defaultID
    }

    private func resolveAccount(id: UUID?, name: String?) -> AccountModel? {
        if let id, let match = accountsByID[id] { return match }
        if let name, let match = accountsByName[name] { return match }
        return nil
    }

    private func fetch<T: PersistentModel>(_ type: T.Type) -> [T] {
        (try? context.fetch(FetchDescriptor<T>())) ?? []
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
