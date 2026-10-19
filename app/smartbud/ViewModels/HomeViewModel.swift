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
        let spent = Money.sum(filtered.filter { !$0.income }.map(\.amount))
        let income = Money.sum(filtered.filter(\.income).map(\.amount))
        let net = income - spent
        totalSpent = Money.double(spent)
        totalIncome = Money.double(income)
        netValue = Money.double(abs(net))
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
        case 2: start = cal.date(byAdding: .day, value: -7, to: now) ?? now
        case 3: start = cal.date(byAdding: .month, value: -1, to: now) ?? now
        default: start = cal.date(byAdding: .year, value: -1, to: now) ?? now
        }
        return txns.filter { ($0.date ?? .distantPast) >= start }
    }
}
