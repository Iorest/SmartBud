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
        incomeCategories = repo.fetch(
            CategoryModel.self,
            predicate: #Predicate { $0.income == true },
            sort: [SortDescriptor(\.order)]
        )
        expenseCategories = repo.fetch(
            CategoryModel.self,
            predicate: #Predicate { $0.income == false },
            sort: [SortDescriptor(\.order)]
        )
    }

    /// Starter categories for a fresh install. Without these the picker has
    /// nothing to choose from and a first transaction cannot be categorised.
    private struct StarterCategory {
        let name: String
        let emoji: String
        let colour: String
        let income: Bool
    }

    private static let starterCategories: [StarterCategory] = [
        StarterCategory(name: "餐饮", emoji: "🍔", colour: "#EC7A58", income: false),
        StarterCategory(name: "交通", emoji: "🚆", colour: "#279AF4", income: false),
        StarterCategory(name: "购物", emoji: "🛍️", colour: "#C56AF7", income: false),
        StarterCategory(name: "居住", emoji: "🏠", colour: "#6E7BF1", income: false),
        StarterCategory(name: "娱乐", emoji: "🎮", colour: "#F3BF56", income: false),
        StarterCategory(name: "医疗", emoji: "💊", colour: "#ED80A2", income: false),
        StarterCategory(name: "工资", emoji: "💼", colour: "#4DBF73", income: true),
        StarterCategory(name: "理财", emoji: "📈", colour: "#408CF2", income: true)
    ]

    /// Adds any starter category the user does not already have. Existing
    /// categories are never renamed or reordered.
    func seedStarterCategories() {
        load()
        for starter in Self.starterCategories {
            let pool = starter.income ? incomeCategories : expenseCategories
            guard !pool.contains(where: { $0.name == starter.name }) else { continue }
            let cat = CategoryModel(
                name: starter.name,
                emoji: starter.emoji,
                colour: starter.colour,
                income: starter.income,
                order: pool.count
            )
            repo.insert(cat)
        }
        repo.save()
        load()
    }

    func create(name: String, emoji: String, colour: String, income: Bool, order: Int) -> CategoryModel {
        let cat = CategoryModel(name: name, emoji: emoji, colour: colour, income: income, order: order)
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
        )
        for transaction in affected {
            transaction.category = nil
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
        repo.fetch(CategoryModel.self, predicate: #Predicate { $0.income == income }, sort: [SortDescriptor(\.order)])
    }

    func findCategory(id: UUID) -> CategoryModel? {
        repo.fetchOne(CategoryModel.self, predicate: #Predicate { $0.id == id })
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
        let nameTaken = categories.contains { $0.wrappedName == name }

        if emojiTaken && nameTaken { return CategoryValidation(error: .duplicate, order: 0) }
        if emojiTaken { return CategoryValidation(error: .duplicateEmoji, order: 0) }
        if nameTaken { return CategoryValidation(error: .duplicateName, order: 0) }
        return CategoryValidation(error: .none, order: (categories.last?.order ?? 0) + 1)
    }
}
