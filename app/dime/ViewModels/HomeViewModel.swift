import SwiftUI
import SwiftData
import Observation

@MainActor
@Observable
final class HomeViewModel{
    static let shared = HomeViewModel()
    private let repo = DataRepository.shared

    var periodType: Int = 3
    var totalSpent: Double = 0
    var totalIncome: Double = 0
    var netValue: Double = 0
    var netPositive: Bool = true
    var recentTransactions: [TransactionModel] = []

    func refresh() {
        let txns = repo.fetch(TransactionModel.self, sort: [SortDescriptor(\.date, order: .reverse)])
        let filtered = filterByPeriod(txns, type: periodType)
        totalSpent = filtered.filter { !$0.income }.reduce(0) { $0 + $1.amount }
        totalIncome = filtered.filter(\.income).reduce(0) { $0 + $1.amount }
        let net = totalIncome - totalSpent
        netValue = abs(net)
        netPositive = net >= 0
        recentTransactions = Array(txns.prefix(10))
    }

    func setPeriod(_ type: Int) { periodType = type; refresh() }

    private func filterByPeriod(_ txns: [TransactionModel], type: Int) -> [TransactionModel] {
        let cal = Calendar.current
        let now = Date.now
        let start: Date
        switch type {
        case 1: start = cal.startOfDay(for: now)
        case 2: start = cal.date(byAdding: .day, value: -7, to: now)!
        case 3: start = cal.date(byAdding: .month, value: -1, to: now)!
        default: start = cal.date(byAdding: .year, value: -1, to: now)!
        }
        return txns.filter { ($0.date ?? .distantPast) >= start }
    }
}
