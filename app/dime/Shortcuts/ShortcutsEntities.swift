//
//  ShortcutsEntities.swift
//  dime
//
//  Created by Rafael Soh on 1/8/23.
//

import AppIntents
import Foundation

@available(iOS 16, *)
struct IncomeCategoryEntity: AppEntity, Identifiable {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = .init(name: LocalizedStringResource("Category"))
    typealias DefaultQueryType = IncomeCategoryQuery
    static let defaultQuery: IncomeCategoryQuery = .init()

    var id: UUID

    @Property(title: LocalizedStringResource("Name"))
    var name: String

    @Property(title: LocalizedStringResource("Emoji"))
    var emoji: String

    @Property(title: LocalizedStringResource("Income"))
    var income: Bool

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(emoji) \(name)")
    }

    init(id: UUID, name: String, emoji: String, income: Bool) {
        self.id = id
        self.name = name
        self.emoji = emoji
        self.income = income
    }
}

@available(iOS 16, *)
struct IncomeCategoryQuery: EntityStringQuery {
    func entities(matching query: String) async throws -> [IncomeCategoryEntity] {
        await MainActor.run {
            CategoryViewModel.shared.getAllCategories(income: true)
                .filter {
                    $0.wrappedName.localizedCaseInsensitiveContains(query) || $0.wrappedEmoji.localizedCaseInsensitiveContains(query)
                }
                .map {
                    IncomeCategoryEntity(id: $0.id, name: $0.wrappedName, emoji: $0.wrappedEmoji, income: $0.income)
                }
        }
    }

    func entities(for identifiers: [IncomeCategoryEntity.ID]) async throws -> [IncomeCategoryEntity] {
        await MainActor.run {
            identifiers.compactMap { identifier in
                if let match = CategoryViewModel.shared.findCategory(id: identifier) {
                    return IncomeCategoryEntity(id: match.id, name: match.wrappedName, emoji: match.wrappedEmoji, income: match.income)
                }
                return nil
            }
        }
    }

    func suggestedEntities() async throws -> [IncomeCategoryEntity] {
        await MainActor.run {
            CategoryViewModel.shared.getAllCategories(income: true)
                .map {
                    IncomeCategoryEntity(id: $0.id, name: $0.wrappedName, emoji: $0.wrappedEmoji, income: $0.income)
                }
        }
    }
}

@available(iOS 16, *)
struct ExpenseCategoryEntity: AppEntity, Identifiable {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = .init(name: LocalizedStringResource("Category"))
    typealias DefaultQueryType = ExpenseCategoryQuery
    static let defaultQuery: ExpenseCategoryQuery = .init()

    var id: UUID

    @Property(title: LocalizedStringResource("Name"))
    var name: String

    @Property(title: LocalizedStringResource("Emoji"))
    var emoji: String

    @Property(title: LocalizedStringResource("Income"))
    var income: Bool

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(emoji) \(name)")
    }

    init(id: UUID, name: String, emoji: String, income: Bool) {
        self.id = id
        self.name = name
        self.emoji = emoji
        self.income = income
    }
}

@available(iOS 16, *)
struct ExpenseCategoryQuery: EntityStringQuery {
    func entities(matching query: String) async throws -> [ExpenseCategoryEntity] {
        await MainActor.run {
            CategoryViewModel.shared.getAllCategories(income: false)
                .filter {
                    $0.wrappedName.localizedCaseInsensitiveContains(query) || $0.wrappedEmoji.localizedCaseInsensitiveContains(query)
                }
                .map {
                    ExpenseCategoryEntity(id: $0.id, name: $0.wrappedName, emoji: $0.wrappedEmoji, income: $0.income)
                }
        }
    }

    func entities(for identifiers: [ExpenseCategoryEntity.ID]) async throws -> [ExpenseCategoryEntity] {
        await MainActor.run {
            identifiers.compactMap { identifier in
                if let match = CategoryViewModel.shared.findCategory(id: identifier) {
                    return ExpenseCategoryEntity(id: match.id, name: match.wrappedName, emoji: match.wrappedEmoji, income: match.income)
                }
                return nil
            }
        }
    }

    func suggestedEntities() async throws -> [ExpenseCategoryEntity] {
        await MainActor.run {
            CategoryViewModel.shared.getAllCategories(income: false)
                .map {
                    ExpenseCategoryEntity(id: $0.id, name: $0.wrappedName, emoji: $0.wrappedEmoji, income: $0.income)
                }
        }
    }
}

@available(iOS 16, *)
struct BudgetEntity: AppEntity, Identifiable {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = .init(name: LocalizedStringResource("Budget"))
    typealias DefaultQueryType = BudgetQuery
    static let defaultQuery: BudgetQuery = .init()

    var id: UUID

    @Property(title: LocalizedStringResource("Name"))
    var name: String

    @Property(title: LocalizedStringResource("Emoji"))
    var emoji: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(emoji) \(name)")
    }

    init(id: UUID, name: String, emoji: String) {
        self.id = id
        self.name = name
        self.emoji = emoji
    }
}

@available(iOS 16, *)
struct BudgetQuery: EntityStringQuery {
    func entities(matching query: String) async throws -> [BudgetEntity] {
        await MainActor.run {
            BudgetViewModel.shared.getAllBudgets()
                .filter {
                    $0.wrappedName.localizedCaseInsensitiveContains(query) || $0.wrappedEmoji.localizedCaseInsensitiveContains(query)
                }
                .map {
                    BudgetEntity(id: $0.id, name: $0.wrappedName, emoji: $0.wrappedEmoji)
                }
        }
    }

    func entities(for identifiers: [BudgetEntity.ID]) async throws -> [BudgetEntity] {
        await MainActor.run {
            identifiers.compactMap { identifier in
                if let match = BudgetViewModel.shared.findBudget(id: identifier) {
                    return BudgetEntity(id: match.id, name: match.wrappedName, emoji: match.wrappedEmoji)
                }
                return nil
            }
        }
    }

    func suggestedEntities() async throws -> [BudgetEntity] {
        await MainActor.run {
            BudgetViewModel.shared.getAllBudgets()
                .map {
                    BudgetEntity(id: $0.id, name: $0.wrappedName, emoji: $0.wrappedEmoji)
                }
        }
    }
}
