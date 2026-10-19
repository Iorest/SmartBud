import Foundation
import SwiftUI
import SwiftData

struct FilteredCategoryDayBudgetView: View {
    @Query private var transactions: [TransactionModel]
    @Binding var totalSpent: Double
    @AppStorage("currency", store: .appGroup) var currency: String = Locale.current.currency?.identifier ?? "USD"
    var currencySymbol: String {
        return Locale.appCurrencySymbol(forCurrencyCode: currency)
    }

    var date: Date

    @AppStorage("showCents", store: .appGroup) var showCents: Bool = true
    @AppStorage("swapTimeLabel", store: .appGroup) var swapTimeLabel: Bool = false
    @AppStorage("showExpenseOrIncomeSign", store: .appGroup)
    var showExpenseOrIncomeSign: Bool = true

    var body: some View {
        VStack(spacing: 0) {
            if transactions.count == 0 {
                NoResultsView(fullscreen: false)
            } else {
                ForEach(transactions, id: \.id) { transaction in
                    SingleTransactionView(transaction: transaction, showCents: showCents, currencySymbol: currencySymbol, currency: currency, swapTimeLabel: swapTimeLabel, future: false, showExpenseOrIncomeSign: showExpenseOrIncomeSign)
                }
            }
        }
        .onAppear {
            DispatchQueue.main.async {
                var holding = 0.0
                transactions.forEach { transaction in

                    holding += transaction.wrappedAmount
                }

                totalSpent = holding
            }
        }
        .onChange(of: date) { _, _ in
            DispatchQueue.main.async {
                var holding = 0.0
                transactions.forEach { transaction in

                    holding += transaction.wrappedAmount
                }

                totalSpent = holding
            }
        }
//        .fullScreenCover(item: $toDelete, onDismiss: {
//            toDelete = nil
//        }) { transaction in
//            DeleteTransactionAlert(toDelete: transaction, stopRecurring: false)
//        }
//        .fullScreenCover(item: $toEdit, onDismiss: {
//            toEdit = nil
//        }) { transaction in
//            TransactionView(toEdit: transaction)
//        }
        .frame(maxHeight: .infinity)
    }

    init(category: CategoryModel?, day: Date, totalSpent: Binding<Double>) {
        date = day
        let now = Date.now
        let past = Date.distantPast
        let future = Date.distantFuture

        if let unwrappedCategory = category {
            let categoryId = unwrappedCategory.id
            _transactions = Query(filter: #Predicate<TransactionModel> {
                ($0.day ?? past) == day && !$0.income && ($0.date ?? future) <= now && $0.category?.id == categoryId
            }, sort: [SortDescriptor(\.date, order: .reverse)])
        } else {
            _transactions = Query(filter: #Predicate<TransactionModel> {
                ($0.day ?? past) == day && !$0.income && ($0.date ?? future) <= now
            }, sort: [SortDescriptor(\.date, order: .reverse)])
        }

        _totalSpent = totalSpent
    }
}

struct FilteredBudgetView: View {
    @Query private var transactions: [TransactionModel]

    @Binding var totalSpent: Double
    var date: Date

    @AppStorage("showCents", store: .appGroup) var showCents: Bool = true
    @AppStorage("currency", store: .appGroup) var currency: String = Locale.current.currency?.identifier ?? "USD"
    var currencySymbol: String {
        return Locale.appCurrencySymbol(forCurrencyCode: currency)
    }

    @AppStorage("showExpenseOrIncomeSign", store: .appGroup)
    var showExpenseOrIncomeSign: Bool = true

    @AppStorage("swapTimeLabel", store: .appGroup) var swapTimeLabel: Bool = false

    private var groupedByDay: [(day: Date, transactions: [TransactionModel])] {
        let grouped = Dictionary(grouping: transactions) { $0.day ?? Date.now }
        return grouped.keys.sorted(by: >).map { day in
            (day: day, transactions: grouped[day]!.sorted { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) })
        }
    }

    private func dayTotal(_ dayTransactions: [TransactionModel]) -> Double {
        dayTransactions.reduce(0.0) { $0 + ($1.income ? $1.amount : -$1.amount) }
    }

    private func dayTotalString(_ total: Double) -> String {
        let numberFormatter = NumberFormatter()
        numberFormatter.locale = Locale.appLocale
        numberFormatter.numberStyle = .currency
        numberFormatter.currencyCode = currency
        numberFormatter.maximumFractionDigits = showCents ? 2 : 0

        if total >= 0 {
            return "+" + (numberFormatter.string(from: NSNumber(value: total)) ?? "$0")
        } else {
            return numberFormatter.string(from: NSNumber(value: total)) ?? "$0"
        }
    }

    var body: some View {
        VStack(spacing: 30) {
            if transactions.count == 0 {
                NoResultsView(fullscreen: false)
            }

            LazyVStack(spacing: 0) {
                ForEach(groupedByDay, id: \.day) { entry in
                    let total = dayTotal(entry.transactions)
                    let dateText = dateConverter(date: entry.day).uppercased()
                    let totalString = abs(total).formatted(.number.precision(.fractionLength(2)))

                    VStack(spacing: 0) {
                        VStack(spacing: 4) {
                            HStack {
                                Text(dateText)
                                Spacer()

                                Text(dayTotalString(total))
                                    .layoutPriority(1)
                            }
                            .font(.system(.callout, design: .rounded).weight(.semibold))
                            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                            .foregroundStyle(Color.SubtitleText)
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel(String(localized: "\(currencySymbol)\(totalString) was spent \(dateConverterAccessibilityLabel(date: entry.day))"))

                            Line()
                                .stroke(Color.Outline, style: StrokeStyle(lineWidth: 1.3, lineCap: .round))
                        }
                        .padding(.horizontal, 10)
                        .padding(.top, 10)

                        ForEach(entry.transactions, id: \.id) { transaction in
                            SingleTransactionView(transaction: transaction, showCents: showCents, currencySymbol: currencySymbol, currency: currency, swapTimeLabel: swapTimeLabel, future: false, showExpenseOrIncomeSign: showExpenseOrIncomeSign)
                        }
                    }
                    .padding(.bottom, 18)
                }
            }
        }
        .frame(maxHeight: .infinity)
        .onAppear {
            totalSpent = transactions.reduce(0.0) { $0 + $1.amount }
        }
        .onChange(of: date) { _, _ in
            totalSpent = transactions.reduce(0.0) { $0 + $1.amount }
        }
    }

    init(category: CategoryModel? = nil, startDate: Date, totalSpent: Binding<Double>, type: Int) {
        date = startDate

        var calendar = Calendar(identifier: .gregorian)

        calendar.firstWeekday = UserDefaults.appGroup.integer(forKey: "firstWeekday")
        calendar.minimumDaysInFirstWeek = 4

        let endDate: Date

        if type == 1 {
            if calendar.isDate(startDate, equalTo: Date.now, toGranularity: .weekOfYear) {
                endDate = Date.now
            } else {
                endDate = calendar.date(byAdding: .day, value: 7, to: startDate) ?? Date.now
            }
        } else if type == 2 {
            if calendar.isDate(startDate, equalTo: Date.now, toGranularity: .month) {
                endDate = Date.now
            } else {
                endDate = calendar.date(byAdding: .month, value: 1, to: startDate) ?? Date.now
            }
        } else {
            if calendar.isDate(startDate, equalTo: Date.now, toGranularity: .year) {
                endDate = Date.now
            } else {
                endDate = calendar.date(byAdding: .year, value: 1, to: startDate) ?? Date.now
            }
        }

        let past = Date.distantPast
        let future = Date.distantFuture

        if let unwrappedCategory = category {
            let categoryId = unwrappedCategory.id
            _transactions = Query(filter: #Predicate<TransactionModel> {
                !$0.income && ($0.date ?? past) >= startDate && ($0.date ?? future) < endDate && $0.category?.id == categoryId
            })
        } else {
            _transactions = Query(filter: #Predicate<TransactionModel> {
                !$0.income && ($0.date ?? past) >= startDate && ($0.date ?? future) < endDate
            })
        }

        _totalSpent = totalSpent
    }
}

