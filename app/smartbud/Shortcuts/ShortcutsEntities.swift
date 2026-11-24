//
//  ShortcutsEntities.swift
//  smartbud
//
//  Created by Iorest on 1/8/23.
//

import AppIntents
import Foundation

/// Picker rows come from the view models, which are scoped to the active
/// book. Intents can also receive ids saved in an old shortcut, so every
/// query re-checks the book here. Archived books stay readable in the app
/// but never offer rows to a Shortcuts picker.
struct ShortcutBookScope {
    let selected: UUID
    let archived: Set<UUID>

    @MainActor
    static var current: ShortcutBookScope {
        ShortcutBookScope(
            // App Group defaults are the one selection source available to
            // the app, macOS and the widget/App Intents process alike.
            selected: BookSelection.current(),
            archived: Set(DataRepository.shared.fetch(BookModel.self).filter { $0.archived }.map { $0.id })
        )
    }

    func contains(_ bookID: UUID?) -> Bool {
        guard BookScope.matches(bookID, selected: selected) else { return false }
        return !archived.contains(bookID ?? BookModel.defaultID)
    }
}

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

struct IncomeCategoryQuery: EntityStringQuery {
    func entities(matching query: String) async throws -> [IncomeCategoryEntity] {
        await MainActor.run {
            let scope = ShortcutBookScope.current
            return CategoryViewModel.shared.getAllCategories(income: true)
                .filter { scope.contains($0.bookID) }
                .filter {
                    $0.wrappedName.localizedStandardContains(query) || $0.wrappedEmoji.localizedStandardContains(query)
                }
                .map {
                    IncomeCategoryEntity(id: $0.id, name: $0.wrappedName, emoji: $0.wrappedEmoji, income: $0.income)
                }
        }
    }

    func entities(for identifiers: [IncomeCategoryEntity.ID]) async throws -> [IncomeCategoryEntity] {
        await MainActor.run {
            let scope = ShortcutBookScope.current
            return identifiers.compactMap { identifier in
                if let match = CategoryViewModel.shared.findCategory(id: identifier),
                   scope.contains(match.bookID) {
                    return IncomeCategoryEntity(
                        id: match.id,
                        name: match.wrappedName,
                        emoji: match.wrappedEmoji,
                        income: match.income
                    )
                }
                return nil
            }
        }
    }

    func suggestedEntities() async throws -> [IncomeCategoryEntity] {
        await MainActor.run {
            let scope = ShortcutBookScope.current
            return CategoryViewModel.shared.getAllCategories(income: true)
                .filter { scope.contains($0.bookID) }
                .map {
                    IncomeCategoryEntity(id: $0.id, name: $0.wrappedName, emoji: $0.wrappedEmoji, income: $0.income)
                }
        }
    }
}

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

struct ExpenseCategoryQuery: EntityStringQuery {
    func entities(matching query: String) async throws -> [ExpenseCategoryEntity] {
        await MainActor.run {
            let scope = ShortcutBookScope.current
            return CategoryViewModel.shared.getAllCategories(income: false)
                .filter { scope.contains($0.bookID) }
                .filter {
                    $0.wrappedName.localizedStandardContains(query) || $0.wrappedEmoji.localizedStandardContains(query)
                }
                .map {
                    ExpenseCategoryEntity(id: $0.id, name: $0.wrappedName, emoji: $0.wrappedEmoji, income: $0.income)
                }
        }
    }

    func entities(for identifiers: [ExpenseCategoryEntity.ID]) async throws -> [ExpenseCategoryEntity] {
        await MainActor.run {
            let scope = ShortcutBookScope.current
            return identifiers.compactMap { identifier in
                if let match = CategoryViewModel.shared.findCategory(id: identifier),
                   scope.contains(match.bookID) {
                    return ExpenseCategoryEntity(
                        id: match.id,
                        name: match.wrappedName,
                        emoji: match.wrappedEmoji,
                        income: match.income
                    )
                }
                return nil
            }
        }
    }

    func suggestedEntities() async throws -> [ExpenseCategoryEntity] {
        await MainActor.run {
            let scope = ShortcutBookScope.current
            return CategoryViewModel.shared.getAllCategories(income: false)
                .filter { scope.contains($0.bookID) }
                .map {
                    ExpenseCategoryEntity(id: $0.id, name: $0.wrappedName, emoji: $0.wrappedEmoji, income: $0.income)
                }
        }
    }
}

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

struct BudgetQuery: EntityStringQuery {
    func entities(matching query: String) async throws -> [BudgetEntity] {
        await MainActor.run {
            let scope = ShortcutBookScope.current
            return BudgetViewModel.shared.getAllBudgets()
                .filter { scope.contains($0.bookID) }
                .filter {
                    $0.wrappedName.localizedStandardContains(query) || $0.wrappedEmoji.localizedStandardContains(query)
                }
                .map {
                    BudgetEntity(id: $0.id, name: $0.wrappedName, emoji: $0.wrappedEmoji)
                }
        }
    }

    func entities(for identifiers: [BudgetEntity.ID]) async throws -> [BudgetEntity] {
        await MainActor.run {
            let scope = ShortcutBookScope.current
            return identifiers.compactMap { identifier in
                if let match = BudgetViewModel.shared.findBudget(id: identifier),
                   scope.contains(match.bookID) {
                    return BudgetEntity(id: match.id, name: match.wrappedName, emoji: match.wrappedEmoji)
                }
                return nil
            }
        }
    }

    func suggestedEntities() async throws -> [BudgetEntity] {
        await MainActor.run {
            let scope = ShortcutBookScope.current
            return BudgetViewModel.shared.getAllBudgets()
                .filter { scope.contains($0.bookID) }
                .map {
                    BudgetEntity(id: $0.id, name: $0.wrappedName, emoji: $0.wrappedEmoji)
                }
        }
    }
}
