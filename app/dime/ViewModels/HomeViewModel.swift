import SwiftUI
import SwiftData

@MainActor
final class HomeViewModel: ObservableObject {
    static let shared = HomeViewModel()
    private let repository = DataService.instance

    // Period type: 1=day, 2=week, 3=month, 4=year
    @Published var periodType: Int = 3
    @Published var totalSpent: Double = 0
    @Published var totalIncome: Double = 0
    @Published var netValue: Double = 0
    @Published var netPositive: Bool = true
    @Published var recentTransactions: [TransactionModel] = []

    func refreshData() {
        totalSpent = repository.getTotalSpent(type: periodType)
        totalIncome = repository.getTotalIncome(type: periodType)
        let net = repository.getTotalNet(type: periodType)
        netValue = net.value
        netPositive = net.positive
        recentTransactions = Array(repository.fetchAllTransactions().prefix(10))
    }

    func setPeriodType(_ type: Int) {
        periodType = type
        refreshData()
    }
}
