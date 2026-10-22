import SwiftUI
import SwiftData
import Observation

@MainActor
@Observable
final class BudgetViewModel {
    static let shared = BudgetViewModel()
    private let repo = DataRepository.shared

    var budgets: [BudgetModel] = []
    var mainBudgets: [MainBudgetModel] = []

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
        let budget = MainBudgetModel(amount: amount, startDate: startDate, type: type)
        repo.insert(budget)
        repo.save()
        load()
        return budget
    }

    func updateMain(_ budget: MainBudgetModel, amount: Double, startDate: Date, type: Int) {
        budget.amount = amount
        budget.startDate = startDate
        budget.type = type
        repo.save()
        load()
    }

    /// Computes a budget's `startDate` for a given time-frame + chosen day/week/month/year.
    /// Pure function — safe to call from views. Mirrors the legacy in-line logic from NewBudgetView.
    /// `timeFrameRaw` accepts the rawValue of `BudgetTimeFrame` (0=day, 1=week, 2=month, 3=year)
    /// so the helper can be used from non-`smartbud` targets (e.g. BudgetIntent) that don't import
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
            let sunday = calendar.date(from: components) ?? day
            let holding = calendar.date(byAdding: .day, value: chosenDayWeek - 1, to: sunday) ?? sunday
            if holding > day {
                return calendar.date(byAdding: .day, value: -7, to: holding) ?? holding
            }
            return holding
        case 2: // .month
            let calendar = Calendar.current
            let components = calendar.dateComponents([.month, .year], from: day)
            let startOfMonth = calendar.date(from: components) ?? day
            let holding = calendar.date(byAdding: .day, value: chosenDayMonth - 1, to: startOfMonth) ?? startOfMonth
            if holding > day {
                return calendar.date(byAdding: .month, value: -1, to: holding) ?? holding
            }
            return holding
        case 3: // .year
            return Calendar.current.startOfDay(for: chosenDayYear)
        default:
            return day
        }
    }

    func delete(_ budget: BudgetModel) { repo.delete(budget); repo.save(); load() }
    func deleteMain(_ budget: MainBudgetModel) { repo.delete(budget); repo.save(); load() }

    /// Persists in-place edits made directly to a BudgetModel/MainBudgetModel (reference types).
    func save() { repo.save(); load() }

    func leftover(_ budget: BudgetModel) -> Double {
        // An unlinked budget (legacy data, or a category removed outside the
        // app) matches every uncategorized row through `nil == nil`; count
        // nothing rather than the whole ledger.
        guard let categoryID = budget.category?.id else {
            return Money.double(Money.cents(budget.amount))
        }
        let spent = Money.sum(repo.fetch(TransactionModel.self).filter { txn in
            let date = txn.date ?? .distantPast
            return date >= budget.startDate && date <= Date.now
                && txn.countsAsSpend && txn.category?.id == categoryID
        }.map(\.wrappedBaseAmount))
        return Money.double(Money.cents(budget.amount) - spent)
    }

    func leftoverOverall(_ budget: MainBudgetModel) -> Double {
        let spent = Money.sum(repo.fetch(TransactionModel.self).filter { txn in
            let date = txn.date ?? .distantPast
            return date >= budget.startDate && date <= Date.now && txn.countsAsSpend
        }.map(\.wrappedBaseAmount))
        return Money.double(Money.cents(budget.amount) - spent)
    }

    func updateDates() {
        for budget in budgets {
            if let start = BudgetRollover.roll(startDate: budget.startDate, type: budget.type) {
                budget.startDate = start
            }
        }
        for mainBudget in mainBudgets {
            if let start = BudgetRollover.roll(startDate: mainBudget.startDate, type: mainBudget.type) {
                mainBudget.startDate = start
            }
        }
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
