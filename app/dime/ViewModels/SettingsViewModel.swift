import SwiftUI
import SwiftData

@MainActor
final class SettingsViewModel: ObservableObject {
    static let shared = SettingsViewModel()
    private let repo = DataRepository.shared

    func fetchAllTransactions() -> [TransactionModel] {
        repo.fetch(TransactionModel.self, sort: [SortDescriptor(\.date, order: .reverse)])
    }

    func eraseAllData() {
        repo.deleteAll()
    }
}
