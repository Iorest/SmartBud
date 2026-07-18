import SwiftUI
import SwiftData

@MainActor
final class BudgetViewModel: ObservableObject {
    static let shared = BudgetViewModel()
    private let repository = DataService.instance

    func fetchAllBudgets() -> [BudgetModel] {
        repository.fetchAllBudgets()
    }

    func findBudget(by id: UUID) throws -> BudgetModel {
        try repository.findBudget(withId: id)
    }

    func createBudget(amount: Double, startDate: Date, type: Int, category: CategoryModel?) {
        let ctx = repository.mainContext
        let budget = BudgetModel(amount: amount, startDate: startDate, type: type)
        budget.category = category
        ctx.insert(budget)
        repository.save(context: ctx)
    }

    func updateBudget(_ budget: BudgetModel, amount: Double, startDate: Date, type: Int) {
        budget.amount = amount
        budget.startDate = startDate
        budget.type = type
        repository.save()
    }

    func deleteBudget(_ budget: BudgetModel) {
        let ctx = repository.mainContext
        ctx.delete(budget)
        repository.save(context: ctx)
    }

    func updateBudgetDates() {
        repository.updateBudgetDates()
    }

    /// Calculate leftover for a specific budget: amount - expenses from start date to now
    func budgetLeftover(for budget: BudgetModel) -> Double {
        let transactions = repository.fetchAllTransactions()
        let relevant = transactions.filter { txn in
            guard let date = txn.date,
                  let budgetCategory = budget.category else { return false }
            return !txn.income &&
                txn.category?.id == budgetCategory.id &&
                date >= budget.startDate &&
                date <= Date.now
        }
        let spent = relevant.reduce(0.0) { $0 + $1.wrappedAmount }
        return budget.amount - spent
    }

    /// Calculate leftover for a main/overall budget: amount - all expenses from start date to now
    func overallBudgetLeftover(amount: Double, startDate: Date) -> Double {
        let transactions = repository.fetchAllTransactions()
        let relevant = transactions.filter { txn in
            guard let date = txn.date else { return false }
            return !txn.income && date >= startDate && date <= Date.now
        }
        let spent = relevant.reduce(0.0) { $0 + $1.wrappedAmount }
        return amount - spent
    }
}
