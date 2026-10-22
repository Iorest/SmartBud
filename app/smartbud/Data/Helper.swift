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

    init(
        note: String = "",
        category: CategoryModel? = nil,
        account: AccountModel? = nil,
        baseAmount: Double? = nil,
        income: Bool = false,
        amount: Double = 0,
        date: Date = Date.now,
        repeatType: Int = 0,
        repeatCoefficient: Int = 0
    ) {
        self.id = UUID()
        self.note = note
        self.category = category
        self.account = account
        self.baseAmount = baseAmount
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
    var hidden: Bool = false
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

extension AccountModel {
    @Transient var wrappedName: String { name }
    @Transient var wrappedEmoji: String { emoji }
    @Transient var wrappedColour: String { colour }
    @Transient var allTransactions: [TransactionModel] {
        (transactions ?? []).sorted { $0.wrappedDate < $1.wrappedDate }
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
    var amount: Double = 0
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
        date: Date = .now,
        note: String? = nil,
        source: AccountModel? = nil,
        destination: AccountModel? = nil
    ) {
        self.id = UUID()
        self.amount = amount
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

// MARK: - Template Transaction

@Model
final class TemplateTransactionModel {
    var amount: Double = 0
    var id: UUID = UUID()
    var income: Bool = false
    var note: String?
    var order: Int = 0
    var recurringCoefficient: Int = 0
    var recurringType: Int = 0
    var category: CategoryModel?

    init(
        note: String = "",
        category: CategoryModel? = nil,
        income: Bool = false,
        amount: Double = 0,
        order: Int = 0,
        repeatType: Int = 0,
        repeatCoefficient: Int = 0
    ) {
        self.id = UUID()
        self.note = note
        self.category = category
        self.income = income
        self.amount = amount
        self.order = order
        self.recurringType = repeatType
        self.recurringCoefficient = repeatCoefficient
    }
}

extension TemplateTransactionModel {
    @Transient var wrappedAmount: Double { amount }
    @Transient var wrappedNote: String { note ?? "" }
    @Transient var wrappedEmoji: String { category?.emoji ?? "" }
    @Transient var wrappedColour: String { category?.colour ?? "" }
}

// MARK: - Shared date utilities
//
// Free functions used by the app (`InsightsViewModel`), widgets (`InsightsWidget`), and App Intents.
// Originally lived in the single legacy data controller.

/// Returns the start-of-day for the current month, offset by `startDay` (1–28).
/// If `startDay` is 1, this is the 1st of the month at 00:00. If `startDay` is 15, it's the 15th at 00:00.
/// Months where the configured `startDay` doesn't exist (e.g. Feb 30) fall back to the last day of the month.
func getStartOfMonth(startDay: Int) -> Date {
    let calendar = Calendar.current
    let now = Date.now
    let comps = calendar.dateComponents([.year, .month], from: now)
    var startComps = comps
    startComps.day = max(1, min(startDay, 28))
    startComps.hour = 0
    startComps.minute = 0
    startComps.second = 0
    return calendar.date(from: startComps) ?? now
}

// MARK: - Line graph
//
// A single sampled data point on the `LineGraph` view, used by the Insights screen and the
// "Get Insights" App Intent snippet. `Equatable` so SwiftUI diffing can skip no-op redraws.

struct LineGraphDataPoint: Equatable, Identifiable {
    let date: Date
    let amount: Double

    var id: Date { date }

    var dateString: String {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale.appLocale
        dateFormatter.setLocalizedDateFormatFromTemplate("MMMd")
        return dateFormatter.string(from: date)
    }

    var monthString: String {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale.appLocale
        dateFormatter.setLocalizedDateFormatFromTemplate("yMMM")
        return dateFormatter.string(from: date)
    }

    var amountString: String {
        if abs(amount) < 1000 {
            return amount.formatted(.number.precision(.fractionLength(2)))
        } else {
            return amount.formatted(.number.precision(.fractionLength(0)))
        }
    }
}
