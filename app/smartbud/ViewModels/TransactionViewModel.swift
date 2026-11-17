import SwiftUI
import SwiftData
import Observation

/// Values written when creating or editing a transaction.
struct TransactionEdit {
    let note: String
    let category: CategoryModel?
    let account: AccountModel?
    let income: Bool
    /// Net amount: what actually left (or entered) the account.
    let amount: Double
    let date: Date
    let repeatType: Int
    let repeatCoefficient: Int
    /// How much was knocked off the listed price. Display-only; `amount`
    /// already excludes it.
    var discount: Double = 0
    /// Expense the user will claim back.
    var reimbursable: Bool = false
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
    let repo = DataRepository.shared

    // MARK: Transaction Creation

    /// Returns `nil` when the store refused the write. The row is rolled back
    /// by `DataRepository.save()`, so callers must not dismiss the form or
    /// report success in that case.
    @discardableResult
    func create(_ edit: TransactionEdit) -> TransactionModel? {
        // Derived once, here: the merchant is a projection of the note, not a
        // second thing for the user to fill in.
        let merchant = MerchantNormalizer.derive(fromNote: edit.note)
        let txn = TransactionModel(note: edit.note, category: edit.category,
                                   account: edit.account,
                                   baseAmount: CurrencyRateStore.shared.convertToBase(
                                       edit.amount, from: edit.account?.currencyCode ?? ""),
                                   income: edit.income, amount: edit.amount, date: edit.date,
                                   repeatType: edit.repeatType,
                                   repeatCoefficient: edit.repeatCoefficient,
                                   discount: edit.discount,
                                   reimbursable: edit.reimbursable,
                                   merchant: merchant?.name,
                                   merchantKey: merchant?.key)
        repo.insert(txn)
        if edit.repeatType > 0 { processRecurring(txn) }
        guard repo.save() else { return nil }
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
    /// Returns `false` when the store refused the write; the context has
    /// already been rolled back, so the caller must keep the form open.
    @discardableResult
    func update(_ txn: TransactionModel, with edit: TransactionEdit) -> Bool {
        // A refund is its own identity: amount, date and account must stay
        // inside the original's remaining amount and use its frozen rate.
        // `RefundLedger.update` enforces all of that; the generic form must not
        // be able to turn a refund into an ordinary expense.
        if txn.isRefund {
            if RefundLedger.update(txn, amount: edit.amount, date: edit.date,
                                   account: edit.account, note: edit.note,
                                   in: repo.context) != nil {
                return false
            }
            return repo.save()
        }
        // Re-derive whenever the note changes: the merchant is a projection of
        // it. A balance adjustment names no merchant at all.
        let merchant = txn.adjustment ? nil : MerchantNormalizer.derive(fromNote: edit.note)
        txn.merchant = merchant?.name
        txn.merchantKey = merchant?.key
        txn.category = edit.category
        txn.account = edit.account
        txn.amount = edit.amount
        txn.baseAmount = CurrencyRateStore.shared.convertToBase(
            edit.amount, from: edit.account?.currencyCode ?? "")
        txn.date = edit.date
        txn.income = edit.income
        txn.discount = edit.discount
        // Only expenses can be claimed back; switching to income drops the flag.
        // Balance adjustments are corrections, never claims.
        txn.reimbursable = edit.reimbursable && !edit.income && !txn.adjustment
        if !txn.reimbursable {
            ReimbursementLedger.unsettle(txn, in: repo.context)
        } else if txn.reimbursedAt != nil {
            ReimbursementLedger.sync(txn, in: repo.context)
        }
        // A written-off claim that changes amount keeps one loss row, in step
        // with it; one that stops being a claim loses its loss row altogether.
        if txn.reimbursable {
            BadDebtLedger.sync(txn, in: repo.context)
        } else {
            BadDebtLedger.clearWriteOff(of: txn, in: repo.context)
        }
        if txn.isReimbursementIncome {
            ReimbursementLedger.syncClaim(from: txn, in: repo.context)
        }

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
        return repo.save()
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
            // instead of spinning forever. The count cap stops a daily
            // recurrence anchored years back from inserting thousands of
            // rows on the main thread (watchdog kill + iCloud storm).
            var generated = 0
            while cursor <= today, generated < Recurrence.maxCatchUp,
                  let next = Recurrence.nextOccurrence(
                      after: Calendar.current.startOfDay(for: cursor),
                      type: txn.recurringType,
                      coefficient: txn.recurringCoefficient) {
                let new = TransactionModel(note: txn.note ?? "", category: txn.category,
                                           account: txn.account, baseAmount: txn.wrappedBaseAmount,
                                           income: txn.income, amount: txn.amount, date: cursor,
                                           discount: txn.discount, reimbursable: txn.reimbursable,
                                           merchant: txn.merchant, merchantKey: txn.merchantKey)
                repo.insert(new)
                new.onceRecurring = true
                cursor = next
                generated += 1
            }
            txn.recurringType = 0
        } else if Calendar.current.isDateInToday(txn.nextTransactionDate) {
            let new = TransactionModel(note: txn.note ?? "", category: txn.category,
                                       account: txn.account, baseAmount: txn.wrappedBaseAmount,
                                       income: txn.income, amount: txn.amount,
                                       date: txn.nextTransactionDate,
                                       discount: txn.discount, reimbursable: txn.reimbursable,
                                       merchant: txn.merchant, merchantKey: txn.merchantKey)
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

    /// Logs a template as a real entry. The caller needs to tell "category
    /// was deleted" apart from "the store refused the write": they need
    /// different messages, and both used to look like success.
    enum ApplyTemplateResult {
        case success
        case missingCategory
        case saveFailed
    }

    func applyTemplate(_ order: Int) -> ApplyTemplateResult {
        guard let tmpl = getTemplate(order), let cat = tmpl.category else { return .missingCategory }
        // Templates carry no account of their own; without the default one the
        // entry would not move any balance and would be missing from the
        // account screens.
        let account = AccountViewModel.shared.defaultAccount(
            lastUsedID: UserDefaults.appGroup.string(forKey: "lastAccountID"))
        let created = create(TransactionEdit(
            note: tmpl.wrappedNote,
            category: cat,
            account: account,
            income: tmpl.income,
            amount: tmpl.wrappedAmount,
            date: .now,
            repeatType: tmpl.recurringType,
            repeatCoefficient: tmpl.recurringCoefficient
        ))
        return created == nil ? .saveFailed : .success
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
        ReimbursementLedger.prepareForDeletion(of: txn, in: repo.context)
        RefundLedger.prepareForDeletion(of: txn, in: repo.context)
        BadDebtLedger.prepareForDeletion(of: txn, in: repo.context)
        TransferFeeLedger.detachFeeRow(txn, in: repo.context)
        repo.delete(txn)
        repo.save()
    }

    /// Deletes several transactions with a single save (batch selection).
    /// Claims take their repayment rows with them, and a repayment row puts
    /// its claim back into the pending list.
    func delete(_ transactions: [TransactionModel]) {
        guard !transactions.isEmpty else { return }
        for txn in transactions {
            ReimbursementLedger.prepareForDeletion(of: txn, in: repo.context)
            RefundLedger.prepareForDeletion(of: txn, in: repo.context)
            TransferFeeLedger.detachFeeRow(txn, in: repo.context)
            repo.delete(txn)
        }
        repo.save()
    }

    /// Moves several transactions to `category` in one save. The income flag
    /// follows the category so a batch can't leave income rows on an expense
    /// category (the form enforces the same rule).
    func setCategory(_ category: CategoryModel?, for transactions: [TransactionModel]) {
        guard !transactions.isEmpty else { return }
        for txn in transactions {
            // A refund belongs to the purchase it gives back; moving it to
            // another category would detach it from the spend it is meant to
            // reduce and leave the new category showing a negative purchase.
            guard !txn.isRefund else { continue }
            // Rows created without a note fall back to the category name, so
            // move that auto-derived note along with the category; a real
            // user-written note is left alone.
            let noteWasCategoryName = txn.note?.isEmpty ?? true
                || txn.note == txn.category?.wrappedName

            txn.category = category
            if let category {
                txn.income = category.income
                // An income row cannot be a reimbursement claim: moving a
                // claim into an income category would otherwise leave it in
                // the pending list and count it as earned money at the same
                // time. Balance adjustments are never claims either.
                if category.income || txn.adjustment {
                    // Clearing the claim without removing its repayment row
                    // would leave the money on the account twice: once as this
                    // row's new income and once as the untouched repayment.
                    if txn.reimbursedAt != nil {
                        ReimbursementLedger.unsettle(txn, in: repo.context)
                    }
                    txn.reimbursable = false
                    txn.reimbursedAt = nil
                    BadDebtLedger.clearWriteOff(of: txn, in: repo.context)
                }
                if noteWasCategoryName {
                    txn.note = category.wrappedName
                }
            }
        }
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
        // Same pairing rules as the immediate delete paths: a claim takes its
        // repayment row with it, and deleting a repayment puts the claim back
        // into the pending list. The rows are deleted but not saved, so
        // `rollback()` still restores the pair as a whole.
        ReimbursementLedger.prepareForDeletion(of: txn, in: repo.context)
        RefundLedger.prepareForDeletion(of: txn, in: repo.context)
        BadDebtLedger.prepareForDeletion(of: txn, in: repo.context)
        TransferFeeLedger.detachFeeRow(txn, in: repo.context)
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
