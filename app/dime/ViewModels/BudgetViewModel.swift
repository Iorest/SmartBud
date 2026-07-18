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

    /// Edits an existing budget in place. Used by the New Budget sheet's "edit" mode.
    func update(_ budget: BudgetModel, amount: Double, startDate: Date, type: Int, category: CategoryModel) {
        budget.amount = amount
        budget.startDate = startDate
        budget.type = type
        budget.category = category
        repo.save()
        load()
    }

    func createMain(amount: Double, startDate: Date, type: Int) -> MainBudgetModel {
        let b = MainBudgetModel(amount: amount, startDate: startDate, type: type)
        repo.insert(b)
        repo.save()
        load()
        return b
    }

    func updateMain(_ b: MainBudgetModel, amount: Double, startDate: Date, type: Int) {
        b.amount = amount
        b.startDate = startDate
        b.type = type
        repo.save()
        load()
    }

    /// Computes a budget's `startDate` for a given time-frame + chosen day/week/month/year.
    /// Pure function — safe to call from views. Mirrors the legacy in-line logic from NewBudgetView.
    /// `timeFrameRaw` accepts the rawValue of `BudgetTimeFrame` (0=day, 1=week, 2=month, 3=year)
    /// so the helper can be used from non-`dime` targets (e.g. BudgetIntent) that don't import
    /// `BudgetTimeFrame`.
    func computeStartDate(timeFrameRaw: Int,
                          chosenDayWeek: Int,
                          chosenDayMonth: Int,
                          chosenDayYear: Date,
                          today: Date = .now) -> Date {
        let day = Calendar.current.startOfDay(for: today)
        switch timeFrameRaw {
        case 0: // .day
            return day
        case 1: // .week
            var calendar = Calendar(identifier: .gregorian)
            calendar.firstWeekday = 1
            calendar.minimumDaysInFirstWeek = 4
            let components = calendar.dateComponents([.weekOfYear, .yearForWeekOfYear], from: day)
            let sunday = calendar.date(from: components)!
            let holding = calendar.date(byAdding: .day, value: chosenDayWeek - 1, to: sunday)!
            if holding > day {
                return calendar.date(byAdding: .day, value: -7, to: holding)!
            }
            return holding
        case 2: // .month
            let calendar = Calendar.current
            let components = calendar.dateComponents([.month, .year], from: day)
            let startOfMonth = calendar.date(from: components)!
            let holding = calendar.date(byAdding: .day, value: chosenDayMonth - 1, to: startOfMonth)!
            if holding > day {
                return calendar.date(byAdding: .month, value: -1, to: holding)!
            }
            return holding
        case 3: // .year
            return Calendar.current.startOfDay(for: chosenDayYear)
        default:
            return day
        }
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
