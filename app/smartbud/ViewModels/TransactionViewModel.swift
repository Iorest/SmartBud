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
    /// Labels to attach. Empty on callers that do not offer a tag picker
    /// (templates, shortcuts, deep links, batch import).
    var tagIDs: [UUID] = []
    /// Receipt photos picked in the form. `nil` leaves an edited row's
    /// existing photos untouched; an empty array removes them all.
    var attachmentData: [Data]? = nil
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
                                   merchantKey: merchant?.key,
                                   bookID: BookState.shared.currentID)
        txn.tagIDs = edit.tagIDs
        repo.insert(txn)
        if edit.repeatType > 0 { processRecurring(txn) }
        guard repo.save() else { return nil }
        applyAttachments(edit.attachmentData, to: txn, replacing: [])
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
        txn.tagIDs = edit.tagIDs
        let previousAttachments = txn.attachments
        // Only expenses can be claimed back; switching to income drops the flag.
        // Balance adjustments are corrections, never claims.
        txn.reimbursable = edit.reimbursable && !edit.income && !txn.adjustment
        if !txn.reimbursable {
            ReimbursementLedger.unsettle(txn, in: repo.context)
        } else if txn.reimbursedAmount > 0 || txn.reimbursedAt != nil {
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
        guard repo.save() else { return false }
        applyAttachments(edit.attachmentData, to: txn, replacing: previousAttachments)
        return true
    }

    /// Writes receipt files for an already-saved row and keeps CKAssets in
    /// step. Called only after `repo.save()` succeeded: a rolled-back insert
    /// must never leave an orphan photo on disk.
    private func applyAttachments(_ data: [Data]?, to txn: TransactionModel,
                                  replacing old: [ReceiptAttachment]) {
        guard let data else { return }
        let refs = (try? ReceiptAttachmentStore.replaceAll(data, for: txn.id)) ?? []
        txn.attachments = refs
        if !old.isEmpty {
            Task { await ReceiptAttachmentSync.remove(attachmentIDs: old.map(\.id)) }
        }
        _ = repo.save()
        if !refs.isEmpty {
            Task { await ReceiptAttachmentSync.upload(refs, transactionID: txn.id) }
        }
    }

    /// Removes a deleted row's files and CKAssets. Staged deletes call this
    /// only on commit, so "Undo" still brings the photos back with the row.
    private func removeAttachments(of txn: TransactionModel) {
        let refs = txn.attachments
        guard !refs.isEmpty else { return }
        try? ReceiptAttachmentStore.removeAll(for: txn.id)
        Task { await ReceiptAttachmentSync.remove(attachmentIDs: refs.map(\.id)) }
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
                                           merchant: txn.merchant, merchantKey: txn.merchantKey,
                                           bookID: txn.bookID)
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
                                       merchant: txn.merchant, merchantKey: txn.merchantKey,
                                       bookID: txn.bookID)
            repo.insert(new)
            new.onceRecurring = true
            txn.recurringType = 0
        }
        repo.save()
    }

    // MARK: Templates

    func getTemplate(_ order: Int) -> TemplateTransactionModel? {
        // `order` is only unique inside one ledger: each book numbers its
        // quick-add slots from zero. Fetch all matches before filtering,
        // otherwise another book's slot can hide this book's template.
        let matches = repo.fetch(TemplateTransactionModel.self,
                                 predicate: #Predicate { $0.order == order })
        return BookScope.scoped(matches, \.bookID,
                                selected: BookState.shared.currentID).first
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
        guard let tmpl = getTemplate(order), let cat = tmpl.category,
              BookScope.matches(cat.bookID, selected: BookState.shared.currentID) else {
            return .missingCategory
        }
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
                                                repeatCoefficient: template.repeatCoefficient,
                                                bookID: BookState.shared.currentID)
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
        guard BookState.shared.isCurrent(template.bookID) else { return }
        repo.delete(template)
        repo.save()
    }

    /// Reassigns `order` for every template to match the sequence in `orderedTemplates`.
    /// Used to persist drag-to-reorder results from the quick-add widget editor.
    func reorderTemplates(_ orderedTemplates: [TemplateTransactionModel]) {
        for (index, tmpl) in orderedTemplates.enumerated() {
            // Another book's slot with the same index is a different template.
            guard BookScope.matches(tmpl.bookID, selected: BookState.shared.currentID) else { continue }
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
        let txns = BookScope.scoped(
            repo.fetch(TransactionModel.self,
                       predicate: #Predicate { $0.income == income },
                       sort: [SortDescriptor(\.date, order: .reverse)]),
            \.bookID, selected: BookState.shared.currentID)
        let filtered = category.map { cat in txns.filter { $0.category?.id == cat.id } } ?? txns

        var seen = Set<String>()
        return filtered.filter { transaction in
            guard transaction.wrappedNote.localizedStandardContains(trimmed) else { return false }
            return seen.insert(transaction.wrappedNote).inserted
        }
    }

    /// Confirmed merchant → category pairs for smart-entry learning. Refunds,
    /// balance adjustments and reimbursements are not spending decisions, so
    /// they must not teach the parser a category.
    func parseHistory(limit: Int = 500) -> [ParseHistoryEntry] {
        repo.fetch(TransactionModel.self,
                   sort: [SortDescriptor(\.date, order: .reverse)])
            .prefix(max(0, limit))
            .compactMap { txn in
                guard let name = txn.merchant, let key = txn.merchantKey,
                      let category = txn.category?.name,
                      !txn.isRefund, !txn.adjustment, !txn.reimbursable
                else { return nil }
                return ParseHistoryEntry(
                    merchantName: name,
                    merchantKey: key,
                    categoryName: category,
                    isIncome: txn.income
                )
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
        removeAttachments(of: txn)
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
            removeAttachments(of: txn)
            repo.delete(txn)
        }
        repo.save()
    }

    /// Batch edit of the same field, with per-row accounting. Linked rows are
    /// skipped instead of aborting the batch, and every skip comes back with
    /// an id and reason for the result alert.
    func batchEdit(category: CategoryModel?, for transactions: [TransactionModel]) -> BatchEditOutcome {
        applyBatch(.category, to: transactions) { applyCategory(category, to: $0) }
    }

    /// A row can only move to a ledger that already owns its account. Linked
    /// refunds, repayments, write-offs and transfer fees stay in the old
    /// ledger, so those rows are skipped with a reason. Labels are per ledger:
    /// only a real move drops their ids; choosing the current ledger keeps
    /// both labels and in-ledger categories.
    func batchEdit(bookID: UUID, for transactions: [TransactionModel]) -> BatchEditOutcome {
        applyBatch(.book, to: transactions, targetBookID: bookID) { txn in
            let oldBookID = txn.bookID ?? BookModel.defaultID
            txn.bookID = bookID
            if let categoryBookID = txn.category?.bookID,
               !BatchEditPolicy.keepsCategory(categoryBookID: categoryBookID, movingTo: bookID) {
                txn.category = nil
            }
            // Labels are per ledger: only a real move drops old-book ids.
            txn.tagIDs = BatchEditPolicy.tagsAfterMove(
                originalBookID: oldBookID, movingTo: bookID, current: txn.tagIDs)
        }
    }

    func batchEdit(note: String, for transactions: [TransactionModel]) -> BatchEditOutcome {
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        return applyBatch(.note, to: transactions) { $0.note = trimmed.isEmpty ? nil : trimmed }
    }

    func batchEdit(date: Date, for transactions: [TransactionModel]) -> BatchEditOutcome {
        let calendar = Calendar(identifier: .gregorian)
        let day = calendar.date(bySettingHour: 0, minute: 0, second: 0, of: date) ?? date
        let month = calendar.date(from: calendar.dateComponents([.month, .year], from: date)) ?? date
        return applyBatch(.date, to: transactions) { txn in
            txn.date = date
            txn.day = day
            txn.month = month
        }
    }

    func batchEdit(account: AccountModel?, for transactions: [TransactionModel]) -> BatchEditOutcome {
        let currency = account?.resolvedCurrencyCode ?? ""
        return applyBatch(.account, to: transactions) { txn in
            // `baseAmount` is frozen at entry time. Silently reusing it after
            // changing to a different currency would corrupt every total.
            guard currency.isEmpty || currency == (txn.account?.resolvedCurrencyCode ?? "") else {
                throw BatchEditError(.currencyMismatch)
            }
            txn.account = account
        }
    }

    func batchEdit(addLabel tagID: UUID, to transactions: [TransactionModel]) -> BatchEditOutcome {
        applyBatch(.labels, to: transactions) { txn in
            if !txn.tagIDs.contains(tagID) { txn.tagIDs.append(tagID) }
        }
    }

    func batchEdit(reimbursable: Bool, for transactions: [TransactionModel]) -> BatchEditOutcome {
        applyBatch(.reimbursable, to: transactions) { txn in
            // Only ordinary expenses can be claims. Refuse instead of
            // reporting "Updated" for a row whose value never changed.
            guard !txn.income && !txn.adjustment else { throw BatchEditError(.invalidValue) }
            txn.reimbursable = reimbursable
            if !txn.reimbursable && (txn.reimbursedAmount > 0 || txn.reimbursedAt != nil) {
                ReimbursementLedger.unsettle(txn, in: repo.context)
            }
        }
    }

    /// SmartBud has no separate "exclude" flags: an ordinary row excluded
    /// from budget and income/expense is an adjustment row with no reason.
    /// Genuine balance corrections carry a reason and are never toggled here.
    func batchEdit(excludedFromTotals: Bool, for transactions: [TransactionModel]) -> BatchEditOutcome {
        applyBatch(.excludeFromTotals, to: transactions) { txn in
            txn.adjustment = excludedFromTotals
            if excludedFromTotals {
                txn.reimbursable = false
            } else {
                txn.adjustmentReason = nil
            }
        }
    }

    /// One save for the whole batch; a rejected row never rolls back the
    /// rows that already succeeded. A failed save is reported as a whole
    /// batch failure: the context has already been rolled back by the repo.
    private func applyBatch(_ field: BatchEditField,
                            to transactions: [TransactionModel],
                            targetBookID: UUID? = nil,
                            mutate: (TransactionModel) throws -> Void) -> BatchEditOutcome {
        guard !transactions.isEmpty else {
            return BatchEditOutcome(applied: 0, rejections: [])
        }
        let byID = Dictionary(transactions.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        // Rows pointed at by a refund / repayment / write-off cannot move
        // alone: that would split the pair across ledgers.
        let referencedIDs = Set(repo.fetch(TransactionModel.self).compactMap {
            $0.refundOf ?? $0.reimbursementOf ?? $0.badDebtOf
        })
        let rows = transactions.map { BatchEditRow($0, referencedIDs: referencedIDs) }
        var editedIDs: [UUID] = []
        let outcome = BatchEditPolicy.apply(rows, field: field, targetBookID: targetBookID) { row in
            guard let txn = byID[row.id] else { throw BatchEditError(.invalidValue) }
            try mutate(txn)
            editedIDs.append(row.id)
        }
        guard outcome.applied == 0 || repo.save() else {
            return BatchEditOutcome(
                applied: 0,
                rejections: editedIDs.map { BatchEditFailure(id: $0, reason: .saveFailed) }
            )
        }
        return outcome
    }

    /// Count shown before a batch action is confirmed. Linked rows are not
    /// counted: they will be skipped with a reason when the action runs.
    func batchEligibleCount(for transactions: [TransactionModel],
                            field: BatchEditField = .note,
                            targetBookID: UUID? = nil) -> Int {
        let referencedIDs = Set(repo.fetch(TransactionModel.self).compactMap {
            $0.refundOf ?? $0.reimbursementOf ?? $0.badDebtOf
        })
        return transactions.filter {
            BatchEditPolicy.rejection(for: BatchEditRow($0, referencedIDs: referencedIDs),
                                      field: field, targetBookID: targetBookID) == nil
        }.count
    }

    private func applyCategory(_ category: CategoryModel?, to txn: TransactionModel) {
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
                if txn.reimbursedAmount > 0 || txn.reimbursedAt != nil {
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

    // MARK: Staged delete (supports "undo" before the delete is committed)

    struct PendingDelete: Identifiable {
        let snapshot: TransactionSnapshot
        var id: UUID { snapshot.id }
    }

    private(set) var pendingDelete: PendingDelete?
    private var pendingDeleteTask: Task<Void, Never>?
    /// Attachment ids of a staged delete. Kept until the delete commits so
    /// "Undo" can still show the receipt photos.
    private var pendingAttachmentIDs: [UUID] = []
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
        pendingAttachmentIDs = txn.attachments.map(\.id)
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
        guard let pending = pendingDelete else { return }
        pendingDelete = nil
        if !pendingAttachmentIDs.isEmpty {
            try? ReceiptAttachmentStore.removeAll(for: pending.id)
            let ids = pendingAttachmentIDs
            pendingAttachmentIDs = []
            Task { await ReceiptAttachmentSync.remove(attachmentIDs: ids) }
        }
        repo.save()
    }

    /// Drops an uncommitted delete when the active book changes. The staged
    /// row belonged to the old book; letting its timer commit after the switch
    /// would delete a row the user can no longer see.
    func discardPendingDelete() {
        guard pendingDelete != nil else { return }
        pendingDeleteTask?.cancel()
        pendingDeleteTask = nil
        pendingDelete = nil
        pendingAttachmentIDs = []
        repo.rollback()
    }

    /// Restores the staged row. `rollback()` normally brings the original
    /// object back intact; the snapshot is a fallback for the rare case where
    /// the context already committed it.
    func undoPendingDelete() {
        pendingDeleteTask?.cancel()
        pendingDeleteTask = nil
        guard let pending = pendingDelete else { return }
        pendingDelete = nil
        pendingAttachmentIDs = []

        repo.rollback()
        let pendingID = pending.id
        if repo.fetchOne(TransactionModel.self, predicate: #Predicate { $0.id == pendingID }) == nil {
            repo.insert(pending.snapshot.makeTransaction())
            repo.save()
        }
    }

}


extension BatchEditRow {
    /// Copies only the identity flags. `hasAdjustmentReason` marks a real
    /// balance correction; a row merely excluded from totals has no reason
    /// and can be included again by a batch action.
    init(_ txn: TransactionModel, referencedIDs: Set<UUID> = []) {
        self.init(
            id: txn.id,
            isRefund: txn.isRefund,
            isReimbursementIncome: txn.isReimbursementIncome,
            isSettledClaim: txn.reimbursable
                && (txn.reimbursedAmount > 0 || txn.reimbursedAt != nil
                    || txn.badDebtAt != nil),
            isBadDebt: txn.badDebtOf != nil,
            isPlanGenerated: txn.installmentOf != nil,
            isReferencedByOtherRows: referencedIDs.contains(txn.id),
            isTransferFee: txn.transferFeeOf != nil,
            // Legacy accounts carry no book id; BookScope reads that as the
            // default book, so normalise here before comparing ledgers.
            accountBookID: txn.account == nil ? nil : (txn.account?.bookID ?? BookModel.defaultID),
            hasAdjustmentReason: txn.adjustmentReason != nil
        )
    }
}
