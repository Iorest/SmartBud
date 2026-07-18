import SwiftUI
import SwiftData
import UniformTypeIdentifiers

@MainActor
final class SettingsViewModel: ObservableObject {
    static let shared = SettingsViewModel()
    private let repository = DataService.instance

    func exportDataToCSV(context: ModelContext) -> URL? {
        let transactions = repository.fetchAllTransactions(context: context)
        let fileName = "export.csv"
        let path = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(fileName)

        var csvText = "Date,Note,Amount,Category,Type\n"

        for transaction in transactions {
            var note = transaction.wrappedNote
            let type = transaction.income ? "Income" : "Expense"

            note.removeAll(where: { $0 == "," })

            csvText += "\(transaction.wrappedDate),\(note),\(String(format: "%.2f", transaction.wrappedAmount)),\(transaction.category?.wrappedName ?? ""),\(type)\n"
        }

        do {
            try csvText.write(to: path, atomically: true, encoding: .utf8)
            return path
        } catch {
            print("Failed to export CSV: \(error)")
            return nil
        }
    }

    func eraseAllData() {
        repository.deleteAll()
    }
}
