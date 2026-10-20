import SwiftUI
import SwiftData
import Observation

/// Values written when creating or editing a transaction.
struct TransactionEdit {
    let note: String
    let category: CategoryModel?
    let income: Bool
    let amount: Double
    let date: Date
    let repeatType: Int
    let repeatCoefficient: Int
}

/// Values written when saving a quick-add template.
struct TemplateDefinition {
    let order: Int
    let note: String
    let category: CategoryModel?
    let income: Bool
    let amount: Double
    let repeatType: Int
    let repeatCoefficient: Int
}

@MainActor
@Observable
final class TransactionViewModel {
    static let shared = TransactionViewModel()
    private let repo = DataRepository.shared

    // MARK: Transaction Creation

    @discardableResult
    func create(_ edit: TransactionEdit) -> TransactionModel {
        let txn = TransactionModel(note: edit.note, category: edit.category,
                                   income: edit.income, amount: edit.amount, date: edit.date,
                                   repeatType: edit.repeatType,
                                   repeatCoefficient: edit.repeatCoefficient)
        repo.insert(txn)
        if edit.repeatType > 0 { processRecurring(txn) }
        repo.save()
        // Fire-in-app review prompt at the 3rd, 10th, and 25th
        // transaction. Apple's StoreKit caps the prompt itself at
        // 3x/year; `ReviewRequester` adds a per-version dedup so
        // each app version asks at most once even if the user hits
        // all three thresholds within it.
        ReviewRequester.recordTransactionCreated()
        return txn
    }

    /// Edits an existing transaction in place. Computes `day` / `month` derived fields
    /// from `date` and re-processes recurring transactions if `repeatType > 0`.
    func update(_ txn: TransactionModel, with edit: TransactionEdit) {
        txn.note = edit.note
        txn.category = edit.category
        txn.amount = edit.amount
        txn.date = edit.date
        txn.income = edit.income

        let calendar = Calendar(identifier: .gregorian)
        txn.day = calendar.date(bySettingHour: 0, minute: 0, second: 0, of: edit.date) ?? Date.now
        let dateComponents = calendar.dateComponents([.month, .year], from: edit.date)
        txn.month = calendar.date(from: dateComponents) ?? Date.now

        if edit.repeatType > 0 {
            txn.onceRecurring = true
            txn.recurringType = edit.repeatType
            txn.recurringCoefficient = edit.repeatCoefficient
            processRecurring(txn)
        } else {
            txn.onceRecurring = false
            txn.recurringType = edit.repeatType
            txn.recurringCoefficient = edit.repeatCoefficient
        }
        repo.save()
    }

    /// Marks a transaction as no longer recurring (idempotent).
    func stopRecurring(_ txn: TransactionModel) {
        txn.recurringType = 0
        txn.onceRecurring = false
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
            var cursor = txn.nextTransactionDate
            // `nextOccurrence` returns nil for an unusable recurrence
            // (unknown type or coefficient <= 0), terminating the loop
            // instead of spinning forever.
            while cursor <= today,
                  let next = Recurrence.nextOccurrence(
                      after: Calendar.current.startOfDay(for: cursor),
                      type: txn.recurringType,
                      coefficient: txn.recurringCoefficient) {
                let new = TransactionModel(note: txn.note ?? "", category: txn.category,
                                           income: txn.income, amount: txn.amount, date: cursor)
                repo.insert(new)
                new.onceRecurring = true
                cursor = next
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
        create(TransactionEdit(
            note: tmpl.wrappedNote,
            category: cat,
            income: tmpl.income,
            amount: tmpl.wrappedAmount,
            date: .now,
            repeatType: tmpl.recurringType,
            repeatCoefficient: tmpl.recurringCoefficient
        ))
    }

    /// All templates ordered by `order` (used by the quick-add widget editor).
    /// Inserts a new template at `order`, or updates the existing template at that `order`.
    @discardableResult
    func createOrUpdateTemplate(_ template: TemplateDefinition) -> TemplateTransactionModel {
        let order = template.order
        if let existing = getTemplate(order) {
            existing.note = template.note
            existing.category = template.category
            existing.income = template.income
            existing.amount = template.amount
            existing.recurringType = template.repeatType
            existing.recurringCoefficient = template.repeatCoefficient
            repo.save()
            return existing
        } else {
            let tmpl = TemplateTransactionModel(note: template.note, category: template.category,
                                                income: template.income, amount: template.amount,
                                                order: order, repeatType: template.repeatType,
                                                repeatCoefficient: template.repeatCoefficient)
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
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        // `localizedStandardContains` is a Foundation convenience that
        // CoreData cannot translate; putting it in a #Predicate raises
        // NSInvalidArgumentException inside NSSQLGenerator and aborts the
        // app. Match by income in SQL, then filter the (small) result set
        // in memory.
        let txns = repo.fetch(TransactionModel.self,
            predicate: #Predicate { $0.income == income },
            sort: [SortDescriptor(\.date, order: .reverse)])
        let filtered = category.map { cat in txns.filter { $0.category?.id == cat.id } } ?? txns

        var seen = Set<String>()
        return filtered.filter { transaction in
            guard transaction.wrappedNote.localizedStandardContains(trimmed) else { return false }
            return seen.insert(transaction.wrappedNote).inserted
        }
    }

    // MARK: Budget Dates

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

    // MARK: Staged delete (supports "undo" before the delete is committed)

    struct PendingDelete: Identifiable {
        let snapshot: TransactionSnapshot
        var id: UUID { snapshot.id }
    }

    private(set) var pendingDelete: PendingDelete?
    private var pendingDeleteTask: Task<Void, Never>?
    private static let undoWindow: Duration = .seconds(6)

    /// Deletes without saving so the row can be restored, and owns the
    /// commit timer here (not in a view's `.task`) so cancellation can never
    /// commit a delete behind the user's back.
    func stageDelete(_ txn: TransactionModel) {
        commitPendingDelete()
        pendingDeleteTask?.cancel()

        let snapshot = TransactionSnapshot(txn)
        repo.delete(txn)
        pendingDelete = PendingDelete(snapshot: snapshot)

        pendingDeleteTask = Task { [weak self] in
            try? await Task.sleep(for: Self.undoWindow)
            guard !Task.isCancelled, let self, self.pendingDelete?.id == snapshot.id else { return }
            self.commitPendingDelete()
        }
    }

    /// Commits the staged delete immediately (or does nothing if there is none).
    func commitPendingDelete() {
        pendingDeleteTask?.cancel()
        pendingDeleteTask = nil
        guard pendingDelete != nil else { return }
        pendingDelete = nil
        repo.save()
    }

    /// Restores the staged row. `rollback()` normally brings the original
    /// object back intact; the snapshot is a fallback for the rare case where
    /// the context already committed it.
    func undoPendingDelete() {
        pendingDeleteTask?.cancel()
        pendingDeleteTask = nil
        guard let pending = pendingDelete else { return }
        pendingDelete = nil

        repo.rollback()
        let pendingID = pending.id
        if repo.fetchOne(TransactionModel.self, predicate: #Predicate { $0.id == pendingID }) == nil {
            repo.insert(pending.snapshot.makeTransaction())
            repo.save()
        }
    }

}
