import SwiftUI
import SwiftData

struct SummaryData: Equatable {
    let spent: Double
    let income: Double
    let net: Double
    let positive: Bool
    let average: Double
}

struct LineGraphDataPoint: Equatable {
    let date: Date
    let amount: Double

    var dateString: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "d MMM"
        return dateFormatter.string(from: date)
    }

    var monthString: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM yy"
        return dateFormatter.string(from: date)
    }

    var amountString: String {
        if abs(amount) < 1000 {
            return String(format: "%.2f", amount)
        } else {
            return String(format: "%.0f", amount)
        }
    }
}

func getStartOfMonth(startDay: Int) -> Date {
    let calendar = Calendar.current
    guard startDay > 0 && startDay <= calendar.maximumRange(of: .day)!.upperBound else {
        let dateComponents = calendar.dateComponents([.month, .year], from: Date.now)
        return calendar.date(from: dateComponents) ?? Date.now
    }
    let today = calendar.startOfDay(for: Date.now)
    let currentDay = calendar.component(.day, from: today)
    var startComponents = DateComponents()
    startComponents.month = currentDay >= startDay ? 0 : -1
    startComponents.day = startDay - currentDay
    return calendar.date(byAdding: startComponents, to: today) ?? Date.now
}

@MainActor
final class InsightsViewModel: ObservableObject {
    static let shared = InsightsViewModel()
    private let repository = DataService.instance

    // 1=week, 2=month, 3=year
    @Published var selectedPeriod: Int = 2
    @Published var summary: SummaryData = SummaryData(spent: 0, income: 0, net: 0, positive: true, average: 0)
    @Published var lineGraphData: [LineGraphDataPoint] = []

    func setPeriod(_ type: Int) {
        selectedPeriod = type
        refresh()
    }

    func refresh() {
        refreshSummary()
        refreshLineGraphData()
    }

    private func refreshSummary() {
        let expenseTransactions = repository.fetchTransactionsForLogView(
            type: selectedPeriod,
            income: false
        )

        let incomeTransactions = repository.fetchTransactionsForLogView(
            type: selectedPeriod,
            income: true
        )

        let spent = expenseTransactions.reduce(0.0) { $0 + $1.wrappedAmount }
        let income = incomeTransactions.reduce(0.0) { $0 + $1.wrappedAmount }
        let net = income - spent

        let positive = net >= 0
        let average = positive ? abs(net) : abs(net)
        summary = SummaryData(spent: spent, income: income, net: abs(net), positive: positive, average: average)
    }

    private func refreshLineGraphData() {
        let allTransactions = repository.fetchAllTransactions()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date.now)
        var dataPoints: [LineGraphDataPoint] = []
        var totalForDay = 0.0

        if selectedPeriod == 1 {
            // Week view
            let lastWeek = calendar.date(byAdding: .day, value: -7, to: today)!
            var changingDate = calendar.date(byAdding: .second, value: 86399, to: lastWeek)!

            let filtered = allTransactions.filter { $0.wrappedDate > lastWeek }
                .sorted { $0.wrappedDate < $1.wrappedDate }

            for transaction in filtered {
                if transaction.wrappedDate < changingDate {
                    totalForDay += transaction.wrappedAmount
                } else {
                    dataPoints.append(LineGraphDataPoint(date: changingDate, amount: totalForDay))
                    changingDate = calendar.date(byAdding: .day, value: 1, to: changingDate)!
                    totalForDay = 0
                    while transaction.wrappedDate > changingDate {
                        dataPoints.append(LineGraphDataPoint(date: changingDate, amount: 0))
                        changingDate = calendar.date(byAdding: .day, value: 1, to: changingDate)!
                    }
                    totalForDay += transaction.wrappedAmount
                }
            }
            dataPoints.append(LineGraphDataPoint(date: changingDate, amount: totalForDay))

            if changingDate < today {
                changingDate = calendar.date(byAdding: .day, value: 1, to: changingDate)!
                while changingDate < today {
                    dataPoints.append(LineGraphDataPoint(date: changingDate, amount: 0))
                    changingDate = calendar.date(byAdding: .day, value: 1, to: changingDate)!
                }
                dataPoints.append(LineGraphDataPoint(date: today, amount: totalForDay))
            }
        } else if selectedPeriod == 2 {
            // Month view
            let lastMonth = calendar.date(byAdding: .month, value: -1, to: today)!
            var changingDate = calendar.date(byAdding: .second, value: 86399, to: lastMonth)!

            let filtered = allTransactions.filter { $0.wrappedDate > lastMonth }
                .sorted { $0.wrappedDate < $1.wrappedDate }

            for transaction in filtered {
                if transaction.wrappedDate < changingDate {
                    totalForDay += transaction.wrappedAmount
                } else {
                    dataPoints.append(LineGraphDataPoint(date: changingDate, amount: totalForDay))
                    changingDate = calendar.date(byAdding: .day, value: 1, to: changingDate)!
                    totalForDay = 0
                    while transaction.wrappedDate > changingDate {
                        dataPoints.append(LineGraphDataPoint(date: changingDate, amount: 0))
                        changingDate = calendar.date(byAdding: .day, value: 1, to: changingDate)!
                    }
                    totalForDay += transaction.wrappedAmount
                }
            }
            dataPoints.append(LineGraphDataPoint(date: changingDate, amount: totalForDay))

            if changingDate < today {
                changingDate = calendar.date(byAdding: .day, value: 1, to: changingDate)!
                while changingDate < today {
                    dataPoints.append(LineGraphDataPoint(date: changingDate, amount: 0))
                    changingDate = calendar.date(byAdding: .day, value: 1, to: changingDate)!
                }
                dataPoints.append(LineGraphDataPoint(date: today, amount: 0))
            }
        } else if selectedPeriod == 3 {
            // Year view
            let dateComponents = calendar.dateComponents([.month, .year], from: Date.now)
            let thisMonth = calendar.date(from: dateComponents)!
            let thisMonthLastYear = calendar.date(byAdding: .year, value: -1, to: thisMonth)!
            let nextMonth = calendar.date(byAdding: .month, value: 1, to: thisMonth)!
            var changingDate = calendar.date(byAdding: .year, value: -1, to: nextMonth)!

            let filtered = allTransactions.filter { $0.wrappedDate > thisMonthLastYear }
                .sorted { $0.wrappedDate < $1.wrappedDate }

            for transaction in filtered {
                if transaction.wrappedDate < changingDate {
                    totalForDay += transaction.wrappedAmount
                } else {
                    let dataDate = calendar.date(byAdding: .day, value: -1, to: changingDate)!
                    dataPoints.append(LineGraphDataPoint(date: dataDate, amount: totalForDay))
                    changingDate = calendar.date(byAdding: .month, value: 1, to: changingDate)!
                    totalForDay = 0
                    while transaction.wrappedDate > changingDate {
                        let newDataDate = calendar.date(byAdding: .day, value: -1, to: changingDate)!
                        dataPoints.append(LineGraphDataPoint(date: newDataDate, amount: 0))
                        changingDate = calendar.date(byAdding: .month, value: 1, to: changingDate)!
                    }
                    totalForDay += transaction.wrappedAmount
                }
            }
            let dataDate = calendar.date(byAdding: .day, value: -1, to: changingDate)!
            dataPoints.append(LineGraphDataPoint(date: dataDate, amount: totalForDay))

            if changingDate < nextMonth {
                changingDate = calendar.date(byAdding: .month, value: 1, to: changingDate)!
                while changingDate < nextMonth {
                    let anotherDataDate = calendar.date(byAdding: .day, value: -1, to: changingDate)!
                    dataPoints.append(LineGraphDataPoint(date: anotherDataDate, amount: 0))
                    changingDate = calendar.date(byAdding: .month, value: 1, to: changingDate)!
                }
                dataPoints.append(LineGraphDataPoint(date: today, amount: 0))
            }
        }

        lineGraphData = dataPoints
    }
}
