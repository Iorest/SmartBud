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
