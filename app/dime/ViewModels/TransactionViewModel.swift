import SwiftUI
import SwiftData

@MainActor
final class TransactionViewModel: ObservableObject {
    static let shared = TransactionViewModel()
    private let repository = DataService.instance

    @discardableResult
    func saveTransaction(
        note: String,
        category: CategoryModel?,
        income: Bool,
        amount: Double,
        date: Date,
        repeatType: Int = 0,
        repeatCoefficient: Int = 0
    ) -> TransactionModel {
        repository.newTransaction(
            note: note,
            category: category,
            income: income,
            amount: amount,
            date: date,
            repeatType: repeatType,
            repeatCoefficient: repeatCoefficient
        )
    }

    func updateRecurring(for transaction: TransactionModel) {
        repository.updateRecurringTransaction(transaction: transaction)
    }

    func updateAllRecurring() {
        repository.updateRecurringTransactions()
    }

    func getSuggestedNotes(
        searchQuery: String,
        category: CategoryModel?,
        income: Bool
    ) -> [TransactionModel] {
        let allTransactions = repository.fetchAllTransactions()
        guard !searchQuery.isEmpty else { return [] }

        let filtered = allTransactions.filter { txn in
            txn.income == income &&
            (txn.wrappedNote.lowercased().hasPrefix(searchQuery.lowercased()) ||
             txn.wrappedNote.lowercased().contains(searchQuery.lowercased()))
        }

        // Deduplicate by note
        var seen = Set<String>()
        return filtered.filter { txn in
            let note = txn.wrappedNote
            guard !seen.contains(note) else { return false }
            seen.insert(note)
            return true
        }
    }

    func newTemplateTransaction(order: Int) {
        repository.newTemplateTransaction(order: order)
    }
}
