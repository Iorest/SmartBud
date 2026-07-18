import SwiftUI
import SwiftData

@MainActor
final class BudgetViewModel: ObservableObject {
    static let shared = BudgetViewModel()
    private let repo = DataRepository.shared

    @Published var budgets: [BudgetModel] = []
    @Published var mainBudgets: [MainBudgetModel] = []

    func load() {
        budgets = repo.fetch(BudgetModel.self, sort: [SortDescriptor(\.dateCreated)])
        mainBudgets = repo.fetch(MainBudgetModel.self)
    }

    func create(amount: Double, startDate: Date, type: Int, category: CategoryModel) -> BudgetModel {
        let budget = BudgetModel(amount: amount, startDate: startDate, type: type)
        budget.category = category
        repo.insert(budget)
        repo.save()
        load()
        return budget
    }

    func createMain(amount: Double, startDate: Date, type: Int) -> MainBudgetModel {
        let b = MainBudgetModel(amount: amount, startDate: startDate, type: type)
        repo.insert(b)
        repo.save()
        load()
        return b
    }

    func delete(_ budget: BudgetModel) { repo.delete(budget); repo.save(); load() }
    func deleteMain(_ b: MainBudgetModel) { repo.delete(b); repo.save(); load() }

    /// Persists in-place edits made directly to a BudgetModel/MainBudgetModel (reference types).
    func save() { repo.save(); load() }

    func leftover(_ budget: BudgetModel) -> Double {
        let spent = repo.fetch(TransactionModel.self).filter { t in
            let d = t.date ?? .distantPast
            return d >= budget.startDate && d <= Date.now && !t.income && t.category?.id == budget.category?.id
        }.reduce(0) { $0 + $1.amount }
        return budget.amount - spent
    }

    func leftoverOverall(_ budget: MainBudgetModel) -> Double {
        let spent = repo.fetch(TransactionModel.self).filter { t in
            let d = t.date ?? .distantPast
            return d >= budget.startDate && d <= Date.now && !t.income
        }.reduce(0) { $0 + $1.amount }
        return budget.amount - spent
    }

    func updateDates() {
        for b in budgets { while b.endDate <= Date.now { b.startDate = b.endDate } }
        for m in mainBudgets { while m.endDate <= Date.now { m.startDate = m.endDate } }
        repo.save()
    }

    // MARK: Stateless queries (for App Intents / Shortcuts, which don't hold onto @Published state)

    func getAllBudgets() -> [BudgetModel] {
        repo.fetch(BudgetModel.self, sort: [SortDescriptor(\.dateCreated)])
    }

    func findBudget(id: UUID) -> BudgetModel? {
        repo.fetchOne(BudgetModel.self, predicate: #Predicate { $0.id == id })
    }

    func getMainBudget() -> MainBudgetModel? {
        repo.fetch(MainBudgetModel.self).first
    }
}
