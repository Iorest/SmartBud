import Foundation
import SwiftData

// Minimal model types needed by ExpenditureWidgetExtension
// These mirror the types in SwiftDataCore.swift

@Model final class WidgetTransactionModel {
    var amount: Double = 0
    var date: Date?
    var id: UUID
    var income: Bool = false
    var note: String?
    var recurringType: Int = 0
    var recurringCoefficient: Int = 0
    var category: WidgetCategoryModel?
    init(note: String = "", category: WidgetCategoryModel? = nil, income: Bool = false, amount: Double = 0, date: Date = Date.now, repeatType: Int = 0, repeatCoefficient: Int = 0) {
        self.id = UUID()
        self.note = note
        self.category = category
        self.income = income
        self.amount = amount
        self.date = date
        self.recurringType = repeatType
        self.recurringCoefficient = repeatCoefficient
    }
}

@Model final class WidgetCategoryModel {
    @Attribute(.unique) var id: UUID
    var name: String = ""
    var emoji: String = ""
    var colour: String = ""
    var income: Bool = false
    var order: Int = 0
    var transactions: [WidgetTransactionModel] = []
    var budget: WidgetBudgetModel?
    init(name: String = "", emoji: String = "", colour: String = "", income: Bool = false, order: Int = 0) {
        self.id = UUID()
        self.name = name
        self.emoji = emoji
        self.colour = colour
        self.income = income
        self.order = order
    }
}

@Model final class WidgetBudgetModel {
    @Attribute(.unique) var id: UUID
    var amount: Double = 0
    var startDate: Date = Date.now
    var type: Int = 0
    var category: WidgetCategoryModel?
    init(amount: Double = 0, startDate: Date = Date.now, type: Int = 3) {
        self.id = UUID()
        self.amount = amount
        self.startDate = startDate
        self.type = type
    }
}

@Model final class WidgetMainBudgetModel {
    var amount: Double = 0
    var startDate: Date = Date.now
    var type: Int = 0
    init(amount: Double = 0, startDate: Date = Date.now, type: Int = 3) {
        self.amount = amount
        self.startDate = startDate
        self.type = type
    }
}
