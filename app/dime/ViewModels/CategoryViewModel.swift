import SwiftUI
import SwiftData

enum CategoryError {
    case none, incomplete, missingName, missingEmoji, duplicate, duplicateName, duplicateEmoji
}

@MainActor
final class CategoryViewModel: ObservableObject {
    static let shared = CategoryViewModel()
    private let repository = DataService.instance

    func fetchCategories(income: Bool) -> [CategoryModel] {
        repository.fetchCategories(income: income)
    }

    func getAllCategories(income: Bool) -> [CategoryModel] {
        repository.getAllCategories(income: income)
    }

    func findCategory(by id: UUID) throws -> CategoryModel {
        try repository.findCategory(withId: id)
    }

    func createCategory(
        name: String,
        emoji: String,
        colour: String,
        income: Bool,
        order: Int
    ) {
        let ctx = repository.mainContext
        let category = CategoryModel(name: name, emoji: emoji, colour: colour, income: income, order: order)
        ctx.insert(category)
        repository.save(context: ctx)
    }

    func editCategory(_ category: CategoryModel, name: String, emoji: String, colour: String) {
        category.name = name
        category.emoji = emoji
        category.colour = colour
        repository.save()
    }

    func deleteCategory(_ category: CategoryModel) {
        let ctx = repository.mainContext
        ctx.delete(category)
        repository.save(context: ctx)
    }

    func reorderCategories(categories: [CategoryModel]) {
        for (index, category) in categories.enumerated() {
            category.order = index
        }
        repository.save()
    }

    func categoryCheck(name: String, emoji: String, income: Bool) -> (error: CategoryError, order: Int) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedName.isEmpty && emoji.isEmpty {
            return (.incomplete, 0)
        }
        if trimmedName.isEmpty {
            return (.missingName, 0)
        }
        if emoji.isEmpty {
            return (.missingEmoji, 0)
        }

        let categories = repository.fetchCategories(income: income)
        var emojiArray: [String] = []
        var nameArray: [String] = []

        for category in categories {
            emojiArray.append(category.wrappedEmoji)
            nameArray.append(category.wrappedName)
        }

        if emojiArray.contains(emoji) && nameArray.contains(trimmedName) {
            return (.duplicate, 0)
        } else if emojiArray.contains(emoji) {
            return (.duplicateEmoji, 0)
        } else if nameArray.contains(trimmedName) {
            return (.duplicateName, 0)
        } else {
            let newOrder = (categories.last?.order ?? -1) + 1
            return (.none, newOrder)
        }
    }

    func categoryCheckEdit(
        name: String,
        emoji: String,
        toEdit: CategoryModel
    ) -> (error: CategoryError, order: Int) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedName.isEmpty && emoji.isEmpty {
            return (.incomplete, 0)
        }
        if trimmedName.isEmpty {
            return (.missingName, 0)
        }
        if emoji.isEmpty {
            return (.missingEmoji, 0)
        }

        var existingCategories = repository.fetchCategories(income: toEdit.income)
        // Remove the category being edited from comparison
        if let idx = existingCategories.firstIndex(where: { $0.id == toEdit.id }) {
            existingCategories.remove(at: idx)
        }

        var emojiArray: [String] = []
        var nameArray: [String] = []

        for category in existingCategories {
            emojiArray.append(category.wrappedEmoji)
            nameArray.append(category.wrappedName)
        }

        if emojiArray.contains(emoji) && nameArray.contains(trimmedName) {
            return (.duplicate, 0)
        } else if emojiArray.contains(emoji) {
            return (.duplicateEmoji, 0)
        } else if nameArray.contains(trimmedName) {
            return (.duplicateName, 0)
        } else {
            let newOrder = (existingCategories.last?.order ?? -1) + 1
            return (.none, newOrder)
        }
    }
}
