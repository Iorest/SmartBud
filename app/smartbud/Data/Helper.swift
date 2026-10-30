//
//  Helper.swift
//  smartbud
//
//  SwiftData @Model definitions for the app, widgets, and App Intents.
//  These replace the legacy CoreData `Transaction`/`Category`/`Budget`/`MainBudget`/`TemplateTransaction`
//  NSManagedObject classes that lived in `MainModel.xcdatamodeld`.
//

import Foundation
import SwiftData
import SwiftUI

// MARK: - Transaction

@Model
final class TransactionModel {
    var amount: Double = 0
    var date: Date?
    var day: Date?
    var id: UUID = UUID()
    var income: Bool = false
    var month: Date?
    var note: String?
    var onceRecurring: Bool = false
    var recurringCoefficient: Int = 0
    var recurringType: Int = 0
    var category: CategoryModel?
    /// Optional so existing rows keep working; new entries set it.
    var account: AccountModel?
    /// Amount converted to the app's base currency at entry time. `nil` on
    /// rows written before multi-currency support (amount already in base).
    var baseAmount: Double?
    /// Discount applied at entry time. `amount` already holds the net total,
    /// so this is display-only ("原价 = amount + discount").
    var discount: Double = 0
    /// Expense the user will claim back. Reimbursable rows are pass-through
    /// money: they stay in the ledger and in the account balance, but never
    /// count towards spend statistics or budgets.
    var reimbursable: Bool = false
    /// Set when the money actually came back.
    var reimbursedAt: Date?
    /// On the income row that pays a claim back: the id of the expense it
    /// settles. The pair moves money back into the account without either
    /// side counting as spend or income.
    var reimbursementOf: UUID?
    /// On the expense row that pays a transfer's fee: the id of the transfer.
    /// The transfer itself carries no money for the fee — this row does — so
    /// the fee can be categorised, budgeted and reported like any expense.
    var transferFeeOf: UUID?
    /// A balance correction written by "调整余额". It moves the account
    /// balance but is neither income nor spend.
    var adjustment: Bool = false
    /// Merchant as the user sees it, derived from the note by
    /// `MerchantNormalizer` ("美团-张亮麻辣烫" → "美团").
    ///
    /// No merchant entity exists: these two strings are the whole of the
    /// merchant data. They die with the row (delete a transaction, or wipe the
    /// store, and they are gone), and renaming a merchant means editing the
    /// rows themselves — nothing else points at them. `nil` means "not
    /// identified": rows written before this field existed, rows whose note
    /// carries no name, and every row `merchantKey == nil` implies.
    var merchant: String?
    /// Grouping key for statistics: the normalised form of `merchant`
    /// (half-width, lower-cased, platform prefix kept, store detail dropped).
    /// Invariant: `merchantKey == nil` exactly when `merchant == nil`, so a
    /// key is never guessed from an unknown name.
    var merchantKey: String?

    init(
        note: String = "",
        category: CategoryModel? = nil,
        account: AccountModel? = nil,
        baseAmount: Double? = nil,
        income: Bool = false,
        amount: Double = 0,
        date: Date = Date.now,
        repeatType: Int = 0,
        repeatCoefficient: Int = 0,
        discount: Double = 0,
        reimbursable: Bool = false,
        reimbursementOf: UUID? = nil,
        transferFeeOf: UUID? = nil,
        adjustment: Bool = false,
        merchant: String? = nil,
        merchantKey: String? = nil
    ) {
        self.id = UUID()
        self.note = note
        self.category = category
        self.account = account
        self.baseAmount = baseAmount
        self.discount = discount
        self.reimbursable = reimbursable
        self.reimbursementOf = reimbursementOf
        self.transferFeeOf = transferFeeOf
        self.adjustment = adjustment
        self.merchant = merchant
        self.merchantKey = merchantKey
        self.income = income
        self.amount = amount
        self.date = date
        self.day = Calendar.current.date(bySettingHour: 0, minute: 0, second: 0, of: date) ?? date
        let comps = Calendar.current.dateComponents([.month, .year], from: date)
        self.month = Calendar.current.date(from: comps) ?? date
        self.recurringType = repeatType
        self.recurringCoefficient = repeatCoefficient
        self.onceRecurring = repeatType > 0
    }
}

extension TransactionModel {
    @Transient var wrappedAmount: Double { amount }
    /// Amount in the app's base currency. Legacy rows (written before
    /// multi-currency) stored the base amount directly.
    @Transient var wrappedBaseAmount: Double { baseAmount ?? amount }
    @Transient var currencyCode: String { account?.currencyCode ?? "" }
    @Transient var wrappedDate: Date { date ?? .now }
    @Transient var wrappedNote: String { note ?? "" }
    @Transient var wrappedCategoryName: String { category?.name ?? "" }
    @Transient var wrappedColour: String { category?.colour ?? "#FFFFFF" }

    /// Price before the discount, when one was recorded.
    @Transient var grossAmount: Double { amount + discount }

    /// Still waiting for the money to come back. A repayment row carries the
    /// same account but is income, so it never shows up as pending.
    @Transient var isPendingReimbursement: Bool {
        reimbursable && !income && reimbursedAt == nil
    }

    /// Income row that settles a claim. It puts the money back into the
    /// account but is not new earnings — counting it would turn a neutral
    /// claim into profit.
    @Transient var isReimbursementIncome: Bool { reimbursementOf != nil }

    /// Counts towards "spent" in insights and budgets. Reimbursable rows are
    /// pass-through and balance adjustments are not spend at all.
    @Transient var countsAsSpend: Bool { !income && !adjustment && !reimbursable }

    /// Counts towards "earned" in insights.
    @Transient var countsAsIncome: Bool { income && !adjustment && !isReimbursementIncome }

    /// A row that belongs in income/spend totals. Adjustments and
    /// reimbursable claims are pass-through money and stay out of both.
    @Transient var countsInTotals: Bool { countsAsSpend || countsAsIncome }

    /// Signed amount in the base currency for net-total maths. Pass-through
    /// rows (balance adjustments and reimbursable claims) count as zero so
    /// "net" always equals income minus the spend figure shown next to it.
    @Transient var signedBaseAmount: Double {
        if countsAsIncome { return wrappedBaseAmount }
        if countsAsSpend { return -wrappedBaseAmount }
        return 0
    }

    @Transient var nextTransactionDate: Date {
        guard let day else { return date ?? .now }
        switch recurringType {
        case 1: return Calendar.current.date(byAdding: .day, value: recurringCoefficient, to: day) ?? day
        case 2: return Calendar.current.date(byAdding: .day, value: recurringCoefficient * 7, to: day) ?? day
        case 3: return Calendar.current.date(byAdding: .month, value: recurringCoefficient, to: day) ?? day
        default: return date ?? .now
        }
    }
}

// MARK: - Category

@Model
final class CategoryModel {
    var id: UUID = UUID()
    var name: String = ""
    var emoji: String = ""
    var colour: String = ""
    var income: Bool = false
    var order: Int = 0
    var dateCreated: Date = Date.now
    /// CloudKit requires all to-many relationships to be optional.
    var transactions: [TransactionModel]?
    var budget: BudgetModel?
    /// CloudKit requires all to-many relationships to be optional.
    var templates: [TemplateTransactionModel]?

    init(
        name: String = "",
        emoji: String = "",
        colour: String = "",
        income: Bool = false,
        order: Int = 0
    ) {
        self.id = UUID()
        self.name = name
        self.emoji = emoji
        self.colour = colour
        self.income = income
        self.order = order
        self.dateCreated = .now
    }
}

extension CategoryModel {
    @Transient var wrappedName: String { name }
    @Transient var wrappedEmoji: String { emoji }
    @Transient var wrappedColour: String { colour }
    @Transient var wrappedDate: Date { dateCreated }
    @Transient var fullName: String { "\(emoji)  \(name)" }
    @Transient var allTransactions: [TransactionModel] {
        (transactions ?? []).sorted { $0.wrappedDate < $1.wrappedDate }
    }
    @Transient var transactionCount: Int { transactions?.count ?? 0 }
}

// MARK: - Account

@Model
final class AccountModel {
    var id: UUID = UUID()
    var name: String = ""
    var emoji: String = ""
    var colour: String = ""
    /// 0 = cash, 1 = debit card, 2 = credit card.
    var kind: Int = 0
    /// ISO code this account is denominated in. Empty means the app's base
    /// currency (rows created before multi-currency support).
    var currencyCode: String = ""
    /// Balance before any recorded transaction.
    var openingBalance: Double = 0
    /// Hidden accounts stay in the list but stop counting towards the total.
    var hidden: Bool = false
    /// Archived accounts leave the default list and the total, but every
    /// transaction, transfer and report still resolves their history.
    var archived: Bool = false
    var order: Int = 0
    var dateCreated: Date = Date.now
    /// CloudKit requires all to-many relationships to be optional.
    var transactions: [TransactionModel]?
    var outgoingTransfers: [TransferModel]?
    var incomingTransfers: [TransferModel]?

    init(
        name: String = "",
        emoji: String = "",
        colour: String = "",
        kind: Int = 0,
        currencyCode: String = "",
        openingBalance: Double = 0,
        order: Int = 0
    ) {
        self.id = UUID()
        self.name = name
        self.emoji = emoji
        self.colour = colour
        self.kind = kind
        self.currencyCode = currencyCode
        self.openingBalance = openingBalance
        self.order = order
        self.dateCreated = .now
    }
}

// MARK: - Currency rate

/// One row per foreign currency the user holds: how many base-currency units
/// one unit is worth. The base currency itself never needs a row (rate = 1).
@Model
final class CurrencyRate {
    var code: String = ""
    var rate: Double = 1
    var updatedAt: Date = Date.now

    init(code: String = "", rate: Double = 1) {
        self.code = code
        self.rate = rate
        self.updatedAt = .now
    }
}

// MARK: - Transfer

/// Money moved between two accounts. Kept out of `TransactionModel` so the
/// ledger, statistics and budgets never treat a transfer as income or spend.
@Model
final class TransferModel {
    var id: UUID = UUID()
    /// Amount leaving the source account, in that account's currency.
    var amount: Double = 0
    /// Amount arriving in the destination account, in its currency. `0` means
    /// same-currency transfer (legacy rows and same-currency transfers).
    var destinationAmount: Double = 0
    /// Fee charged on top of `amount`, in the source account's currency. Kept
    /// for display only: the money is booked as an expense row linked through
    /// `TransactionModel.transferFeeOf`, so the fee can be categorised and
    /// counted in spend without being charged twice.
    var fee: Double = 0
    var date: Date = Date.now
    var note: String?
    var dateCreated: Date = Date.now
    // Two relationships to the same type need explicit inverses, otherwise
    // CloudKit refuses to load the store ("all relationships have an inverse").
    @Relationship(inverse: \AccountModel.outgoingTransfers)
    var source: AccountModel?
    @Relationship(inverse: \AccountModel.incomingTransfers)
    var destination: AccountModel?

    init(
        amount: Double = 0,
        destinationAmount: Double = 0,
        fee: Double = 0,
        date: Date = .now,
        note: String? = nil,
        source: AccountModel? = nil,
        destination: AccountModel? = nil
    ) {
        self.id = UUID()
        self.amount = amount
        self.destinationAmount = destinationAmount
        self.fee = fee
        self.date = date
        self.note = note
        self.source = source
        self.destination = destination
        self.dateCreated = .now
    }
}

extension TransferModel {
    @Transient var wrappedDate: Date { date }
    @Transient var wrappedNote: String { note ?? "" }
    /// What lands in the destination account (falls back to `amount`).
    @Transient var receivedAmount: Double {
        destinationAmount > 0 ? destinationAmount : amount
    }
    /// Effective rate applied by this transfer, when it crossed currencies.
    @Transient var impliedRate: Double? {
        guard destinationAmount > 0, amount > 0 else { return nil }
        return destinationAmount / amount
    }
    /// What leaves the source account, fee included.
    /// What leaves the sending account. The fee is a separate expense row, so
    /// charging it here as well would deduct it twice.
    @Transient var outgoingTotal: Double { amount }
}

// MARK: - Category Budget

@Model
final class BudgetModel {
    var id: UUID = UUID()
    var amount: Double = 0
    var startDate: Date = Date.now
    var dateCreated: Date = Date.now
    var type: Int = 0
    var green: Bool = false
    var category: CategoryModel?

    init(amount: Double = 0, startDate: Date = Date.now, type: Int = 3) {
        self.id = UUID()
        self.amount = amount
        self.startDate = startDate
        self.dateCreated = Date.now
        self.type = type
    }
}

extension BudgetModel {
    @Transient var wrappedDate: Date { startDate }
    @Transient var wrappedName: String { category?.name ?? "" }
    @Transient var wrappedEmoji: String { category?.emoji ?? "" }
    @Transient var wrappedColour: String { category?.colour ?? "#FFFFFF" }
    @Transient var fullName: String { "\(wrappedEmoji) \(wrappedName)" }

    @Transient var endDate: Date {
        BudgetPeriod.endDate(from: startDate, type: type)
    }
}

// MARK: - Main (overall) Budget

@Model
final class MainBudgetModel {
    var amount: Double = 0
    var startDate: Date = Date.now
    var dateCreated: Date = Date.now
    var type: Int = 0
    var green: Bool = false

    init(amount: Double = 0, startDate: Date = Date.now, type: Int = 3) {
        self.amount = amount
        self.startDate = startDate
        self.dateCreated = .now
        self.type = type
    }
}

extension MainBudgetModel {
    @Transient var wrappedDate: Date { startDate }

    @Transient var endDate: Date {
        BudgetPeriod.endDate(from: startDate, type: type)
    }
}
