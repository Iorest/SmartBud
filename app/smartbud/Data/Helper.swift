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

    init(
        note: String = "",
        category: CategoryModel? = nil,
        income: Bool = false,
        amount: Double = 0,
        date: Date = Date.now,
        repeatType: Int = 0,
        repeatCoefficient: Int = 0
    ) {
        self.id = UUID()
        self.note = note
        self.category = category
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
    var transactions: [TransactionModel]? = nil
    var budget: BudgetModel?
    /// CloudKit requires all to-many relationships to be optional.
    var templates: [TemplateTransactionModel]? = nil

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
        switch type {
        case 1: return Calendar.current.date(byAdding: .day, value: 1, to: startDate) ?? startDate
        case 2: return Calendar.current.date(byAdding: .day, value: 7, to: startDate) ?? startDate
        case 3: return Calendar.current.date(byAdding: .month, value: 1, to: startDate) ?? startDate
        case 4: return Calendar.current.date(byAdding: .year, value: 1, to: startDate) ?? startDate
        default: return startDate
        }
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
        switch type {
        case 1: return Calendar.current.date(byAdding: .day, value: 1, to: startDate) ?? startDate
        case 2: return Calendar.current.date(byAdding: .day, value: 7, to: startDate) ?? startDate
        case 3: return Calendar.current.date(byAdding: .month, value: 1, to: startDate) ?? startDate
        case 4: return Calendar.current.date(byAdding: .year, value: 1, to: startDate) ?? startDate
        default: return startDate
        }
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
// Originally lived in the legacy `DataController.swift`.

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
        dateFormatter.dateFormat = "d MMM"
        return dateFormatter.string(from: date)
    }

    var monthString: String {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale.appLocale
        dateFormatter.dateFormat = "MMM yy"
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
