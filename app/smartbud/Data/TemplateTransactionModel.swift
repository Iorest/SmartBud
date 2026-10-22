//
//  TemplateTransactionModel.swift
//  smartbud
//
//  Saved quick-add templates. Split out of Helper.swift to keep that file
//  within the project's length limit; the model itself is unchanged.
//

import Foundation
import SwiftData

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
