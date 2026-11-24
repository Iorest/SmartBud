import SwiftUI
import SwiftData
import Observation

/// Result of validating a new or edited category. Replaces a three-member
/// tuple so call sites read `result.error` / `result.order` instead of
/// positional destructuring.
struct CategoryValidation {
    let error: CategoryError
    let order: Int
}

@MainActor
@Observable
final class CategoryViewModel {
    static let shared = CategoryViewModel()
    private let repo = DataRepository.shared

    var incomeCategories: [CategoryModel] = []
    var expenseCategories: [CategoryModel] = []

    func load() {
        let selected = BookSelection.current()
        incomeCategories = BookScope.scoped(repo.fetch(
            CategoryModel.self,
            predicate: #Predicate { $0.income == true },
            sort: [SortDescriptor(\.order)]
        ), \.bookID, selected: selected)
        expenseCategories = BookScope.scoped(repo.fetch(
            CategoryModel.self,
            predicate: #Predicate { $0.income == false },
            sort: [SortDescriptor(\.order)]
        ), \.bookID, selected: selected)
    }

    /// Starter categories for a fresh install. Without these the picker has
    /// nothing to choose from and a first transaction cannot be categorised.
    private struct StarterCategory {
        /// Localisation key, not a name: with the names hardcoded in Chinese
        /// an English or Traditional-Chinese install got eight Simplified
        /// categories that could never be translated.
        let nameKey: String
        let emoji: String
        let colour: String
        let income: Bool
    }

    private static let starterCategories: [StarterCategory] = [
        StarterCategory(nameKey: "Food", emoji: "🍔", colour: "#EC7A58", income: false),
        StarterCategory(nameKey: "Transport", emoji: "🚆", colour: "#279AF4", income: false),
        StarterCategory(nameKey: "Shopping", emoji: "🛍️", colour: "#C56AF7", income: false),
        StarterCategory(nameKey: "Housing", emoji: "🏠", colour: "#6E7BF1", income: false),
        StarterCategory(nameKey: "Entertainment", emoji: "🎮", colour: "#F3BF56", income: false),
        StarterCategory(nameKey: "Healthcare", emoji: "💊", colour: "#ED80A2", income: false),
        StarterCategory(nameKey: "Paycheck", emoji: "💼", colour: "#4DBF73", income: true),
        StarterCategory(nameKey: "Investment", emoji: "📈", colour: "#408CF2", income: true)
    ]

    /// Adds any starter category the user does not already have. Existing
    /// categories are never renamed or reordered.
    func seedStarterCategories() {
        load()
        for starter in Self.starterCategories {
            let name = String.appLocalized(starter.nameKey)
            let pool = starter.income ? incomeCategories : expenseCategories
            guard !pool.contains(where: { sameName($0.wrappedName, name) }) else { continue }
            let cat = CategoryModel(
                name: name,
                emoji: starter.emoji,
                colour: starter.colour,
                income: starter.income,
                order: pool.count,
                bookID: BookSelection.current()
            )
            repo.insert(cat)
        }
        repo.save()
        load()
    }

    func create(name: String, emoji: String, colour: String, income: Bool, order: Int) -> CategoryModel {
        let cat = CategoryModel(name: name, emoji: emoji, colour: colour, income: income,
                                order: order, bookID: BookSelection.current())
        repo.insert(cat)
        repo.save()
        load()
        return cat
    }

    func update(_ category: CategoryModel, name: String, emoji: String, colour: String) {
        category.name = name
        category.emoji = emoji
        category.colour = colour
        repo.save()
        load()
    }

    func delete(_ category: CategoryModel) {
        // Deleting a category must not take its history with it: SwiftData's
        // default rule nullifies the relationship, but a future delete rule
        // change would silently cascade. Clear the link explicitly so the
        // confirmation copy is always true.
        let id = category.id
        let affected = repo.fetch(
            TransactionModel.self,
            predicate: #Predicate { $0.category?.id == id }
        ).filter { BookScope.matches($0.bookID, selected: BookSelection.current()) }
        for transaction in affected {
            transaction.category = nil
        }

        // A category budget has no meaning without its category: keeping it
        // would leave an unnamed budget whose `nil == nil` category match
        // counts every uncategorized row.
        let attachedBudgets = repo.fetch(
            BudgetModel.self,
            predicate: #Predicate { $0.category?.id == id }
        ).filter { BookScope.matches($0.bookID, selected: BookSelection.current()) }
        for budget in attachedBudgets {
            repo.delete(budget)
        }

        repo.delete(category)
        repo.save()
        load()
    }

    func reorder(from source: IndexSet, to destination: Int, income: Bool) {
        var cats = income ? incomeCategories : expenseCategories
        cats.move(fromOffsets: source, toOffset: destination)
        for (index, category) in cats.enumerated() { category.order = index }
        repo.save()
        load()
    }

    // MARK: Stateless queries (for App Intents / Shortcuts, which don't hold onto @Published state)

    func getAllCategories(income: Bool) -> [CategoryModel] {
        BookScope.scoped(
            repo.fetch(CategoryModel.self,
                       predicate: #Predicate { $0.income == income },
                       sort: [SortDescriptor(\.order)]),
            \.bookID, selected: BookSelection.current())
    }

    func findCategory(id: UUID) -> CategoryModel? {
        guard let category = repo.fetchOne(CategoryModel.self, predicate: #Predicate { $0.id == id }),
              BookScope.matches(category.bookID, selected: BookSelection.current()) else { return nil }
        return category
    }

    // Validation

    func validate(name: String, emoji: String, income: Bool) -> CategoryValidation {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if let error = missingFieldError(name: trimmedName, emoji: emoji) {
            return CategoryValidation(error: error, order: 0)
        }
        let categories = income ? incomeCategories : expenseCategories
        return validation(among: categories, emoji: emoji, name: trimmedName)
    }

    func validateEdit(name: String, emoji: String, exclude: CategoryModel) -> CategoryValidation {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if let error = missingFieldError(name: trimmedName, emoji: emoji) {
            return CategoryValidation(error: error, order: 0)
        }
        let categories = (exclude.income ? incomeCategories : expenseCategories)
            .filter { $0.id != exclude.id }
        return validation(among: categories, emoji: emoji, name: trimmedName)
    }

    /// Two names that differ only in case or diacritics are the same label.
    private func sameName(_ lhs: String, _ rhs: String) -> Bool {
        lhs.compare(rhs, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
    }

    private func missingFieldError(name: String, emoji: String) -> CategoryError? {
        if name.isEmpty && emoji.isEmpty { return .incomplete }
        if name.isEmpty { return .missingName }
        if emoji.isEmpty { return .missingEmoji }
        return nil
    }

    private func validation(among categories: [CategoryModel],
                            emoji: String,
                            name: String) -> CategoryValidation {
        let emojiTaken = categories.contains { $0.wrappedEmoji == emoji }
        // "food" and "Food" are the same category to the user; comparing
        // case-sensitively let a duplicate through.
        let nameTaken = categories.contains { sameName($0.wrappedName, name) }

        if emojiTaken && nameTaken { return CategoryValidation(error: .duplicate, order: 0) }
        if emojiTaken { return CategoryValidation(error: .duplicateEmoji, order: 0) }
        if nameTaken { return CategoryValidation(error: .duplicateName, order: 0) }
        return CategoryValidation(error: .none, order: (categories.last?.order ?? 0) + 1)
    }
}
