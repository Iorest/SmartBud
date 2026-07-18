import SwiftUI
import SwiftData

@MainActor
final class TransactionViewModel: ObservableObject {
    static let shared = TransactionViewModel()
    private let repo = DataRepository.shared

    // MARK: Transaction Creation

    @discardableResult
    func create(note: String, category: CategoryModel?, income: Bool, amount: Double,
                date: Date = .now, repeatType: Int = 0, repeatCoefficient: Int = 0) -> TransactionModel {
        let txn = TransactionModel(note: note, category: category, income: income,
                                   amount: amount, date: date,
                                   repeatType: repeatType, repeatCoefficient: repeatCoefficient)
        repo.insert(txn)
        if repeatType > 0 { processRecurring(txn) }
        repo.save()
        return txn
    }

    /// Edits an existing transaction in place. Computes `day` / `month` derived fields
    /// from `date` and re-processes recurring transactions if `repeatType > 0`.
    func update(_ txn: TransactionModel, note: String, category: CategoryModel?,
                income: Bool, amount: Double, date: Date,
                repeatType: Int, repeatCoefficient: Int) {
        txn.note = note
        txn.category = category
        txn.amount = amount
        txn.date = date
        txn.income = income

        let calendar = Calendar(identifier: .gregorian)
        txn.day = calendar.date(bySettingHour: 0, minute: 0, second: 0, of: date) ?? Date.now
        let dateComponents = calendar.dateComponents([.month, .year], from: date)
        txn.month = calendar.date(from: dateComponents) ?? Date.now

        if repeatType > 0 {
            txn.onceRecurring = true
            txn.recurringType = repeatType
            txn.recurringCoefficient = repeatCoefficient
            processRecurring(txn)
        } else {
            txn.onceRecurring = false
            txn.recurringType = repeatType
            txn.recurringCoefficient = repeatCoefficient
        }
        repo.save()
    }

    /// Marks a transaction as no longer recurring (idempotent).
    func stopRecurring(_ txn: TransactionModel) {
        txn.recurringType = 0
        repo.save()
    }

    // MARK: Recurring

    func updateAllRecurring() {
        let recurring = repo.fetch(TransactionModel.self, predicate: #Predicate { $0.recurringType > 0 })
        for txn in recurring { processRecurring(txn) }
    }

    func processRecurring(_ txn: TransactionModel) {
        let today = Calendar.current.startOfDay(for: Date.now)
        if txn.nextTransactionDate < today {
            var d = txn.nextTransactionDate
            while d <= today {
                let new = TransactionModel(note: txn.note ?? "", category: txn.category,
                                           income: txn.income, amount: txn.amount, date: d)
                repo.insert(new)
                new.onceRecurring = true
                d = new.nextTransactionDate
            }
            txn.recurringType = 0
        } else if Calendar.current.isDateInToday(txn.nextTransactionDate) {
            let new = TransactionModel(note: txn.note ?? "", category: txn.category,
                                       income: txn.income, amount: txn.amount, date: txn.nextTransactionDate)
            repo.insert(new)
            new.onceRecurring = true
            txn.recurringType = 0
        }
        repo.save()
    }

    // MARK: Templates

    func getTemplate(_ order: Int) -> TemplateTransactionModel? {
        repo.fetchOne(TemplateTransactionModel.self, predicate: #Predicate { $0.order == order })
    }

    func applyTemplate(_ order: Int) {
        guard let tmpl = getTemplate(order), let cat = tmpl.category else { return }
        create(note: tmpl.wrappedNote, category: cat, income: tmpl.income,
               amount: tmpl.wrappedAmount, repeatType: tmpl.recurringType,
               repeatCoefficient: tmpl.recurringCoefficient)
    }

    /// All templates ordered by `order` (used by the quick-add widget editor).
    func allTemplates() -> [TemplateTransactionModel] {
        repo.fetch(TemplateTransactionModel.self, sort: [SortDescriptor(\.order)])
    }

    /// Inserts a new template at `order`, or updates the existing template at that `order`.
    @discardableResult
    func createOrUpdateTemplate(order: Int, note: String, category: CategoryModel?, income: Bool,
                                amount: Double, repeatType: Int, repeatCoefficient: Int) -> TemplateTransactionModel {
        if let existing = getTemplate(order) {
            existing.note = note
            existing.category = category
            existing.income = income
            existing.amount = amount
            existing.recurringType = repeatType
            existing.recurringCoefficient = repeatCoefficient
            repo.save()
            return existing
        } else {
            let tmpl = TemplateTransactionModel(note: note, category: category, income: income,
                                                amount: amount, order: order,
                                                repeatType: repeatType, repeatCoefficient: repeatCoefficient)
            repo.insert(tmpl)
            repo.save()
            return tmpl
        }
    }

    /// Deletes the template at `order` (no-op if there is none).
    func deleteTemplate(order: Int) {
        guard let tmpl = getTemplate(order) else { return }
        repo.delete(tmpl)
        repo.save()
    }

    /// Deletes the given template.
    func deleteTemplate(_ template: TemplateTransactionModel) {
        repo.delete(template)
        repo.save()
    }

    /// Reassigns `order` for every template to match the sequence in `orderedTemplates`.
    /// Used to persist drag-to-reorder results from the quick-add widget editor.
    func reorderTemplates(_ orderedTemplates: [TemplateTransactionModel]) {
        for (index, tmpl) in orderedTemplates.enumerated() {
            tmpl.order = index
        }
        repo.save()
    }

    // MARK: Suggestions

    func suggestedNotes(query: String, category: CategoryModel?, income: Bool) -> [TransactionModel] {
        let txns = repo.fetch(TransactionModel.self,
            predicate: #Predicate { ($0.note ?? "").localizedStandardContains(query) && $0.income == income },
            sort: [SortDescriptor(\.date, order: .reverse)])
        let filtered = category.map { cat in txns.filter { $0.category?.id == cat.id } } ?? txns
        var seen = Set<String>()
        return filtered.filter { seen.insert($0.wrappedNote).inserted }
    }

    // MARK: Budget Dates

    func updateBudgetDates() {
        for b in repo.fetch(BudgetModel.self) { while b.endDate <= Date.now { b.startDate = b.endDate } }
        for m in repo.fetch(MainBudgetModel.self) { while m.endDate <= Date.now { m.startDate = m.endDate } }
        repo.save()
    }

    // MARK: Editing / Deletion

    /// Persists in-place edits made directly to a TransactionModel (a reference type),
    /// e.g. after mutating its fields in a View/ViewModel.
    func save() {
        repo.save()
    }

    func delete(_ txn: TransactionModel) {
        repo.delete(txn)
        repo.save()
    }

    // MARK: Staged delete (supports "undo" toast before the delete is committed)

    /// Marks a transaction for deletion without saving yet, so it can still be rolled back.
    func stageDelete(_ txn: TransactionModel) {
        repo.delete(txn)
    }

    /// Commits any staged (unsaved) changes, such as a staged delete.
    func commitPendingChanges() {
        repo.save()
    }

    /// Reverts any staged (unsaved) changes, such as a staged delete.
    func rollback() {
        repo.rollback()
    }
}
