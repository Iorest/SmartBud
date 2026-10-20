import SwiftUI
import SwiftData
import Observation

@MainActor
@Observable
final class CategoryViewModel{
    static let shared = CategoryViewModel()
    private let repo = DataRepository.shared

    var incomeCategories: [CategoryModel] = []
    var expenseCategories: [CategoryModel] = []

    func load() {
        incomeCategories = repo.fetch(CategoryModel.self, predicate: #Predicate { $0.income == true }, sort: [SortDescriptor(\.order)])
        expenseCategories = repo.fetch(CategoryModel.self, predicate: #Predicate { $0.income == false }, sort: [SortDescriptor(\.order)])
    }

    /// Starter categories for a fresh install. Without these the picker has
    /// nothing to choose from and a first transaction cannot be categorised.
    private static let starterCategories: [(name: String, emoji: String, colour: String, income: Bool)] = [
        ("餐饮", "🍔", "#EC7A58", false),
        ("交通", "🚆", "#279AF4", false),
        ("购物", "🛍️", "#C56AF7", false),
        ("居住", "🏠", "#6E7BF1", false),
        ("娱乐", "🎮", "#F3BF56", false),
        ("医疗", "💊", "#ED80A2", false),
        ("工资", "💼", "#4DBF73", true),
        ("理财", "📈", "#408CF2", true)
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
        for (i, cat) in cats.enumerated() { cat.order = i }
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
    func validate(name: String, emoji: String, income: Bool) -> (valid: Bool, error: CategoryError, order: Int) {
        let n = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if n.isEmpty && emoji.isEmpty { return (false, .incomplete, 0) }
        if n.isEmpty { return (false, .missingName, 0) }
        if emoji.isEmpty { return (false, .missingEmoji, 0) }
        let cats = income ? incomeCategories : expenseCategories
        if cats.contains(where: { $0.wrappedEmoji == emoji }) && cats.contains(where: { $0.wrappedName == name }) { return (false, .duplicate, 0) }
        if cats.contains(where: { $0.wrappedEmoji == emoji }) { return (false, .duplicateEmoji, 0) }
        if cats.contains(where: { $0.wrappedName == name }) { return (false, .duplicateName, 0) }
        return (true, .none, (cats.last?.order ?? 0) + 1)
    }

    func validateEdit(name: String, emoji: String, exclude: CategoryModel) -> (valid: Bool, error: CategoryError, order: Int) {
        let n = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if n.isEmpty && emoji.isEmpty { return (false, .incomplete, 0) }
        if n.isEmpty { return (false, .missingName, 0) }
        if emoji.isEmpty { return (false, .missingEmoji, 0) }
        let cats = (exclude.income ? incomeCategories : expenseCategories).filter { $0.id != exclude.id }
        if cats.contains(where: { $0.wrappedEmoji == emoji }) && cats.contains(where: { $0.wrappedName == name }) { return (false, .duplicate, 0) }
        if cats.contains(where: { $0.wrappedEmoji == emoji }) { return (false, .duplicateEmoji, 0) }
        if cats.contains(where: { $0.wrappedName == name }) { return (false, .duplicateName, 0) }
        return (true, .none, (cats.last?.order ?? 0) + 1)
    }
}
