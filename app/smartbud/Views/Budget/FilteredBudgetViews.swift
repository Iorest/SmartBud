import Foundation
import SwiftUI
import SwiftData

struct FilteredCategoryDayBudgetView: View {
    @Query private var transactions: [TransactionModel]
    @Environment(OverallTransactionManager.self) private var transactionManager
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
        List {
            if transactions.count == 0 {
                NoResultsView(fullscreen: false)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            } else {
                ForEach(transactions, id: \.id) { transaction in
                    SingleTransactionView(
                        transaction: transaction,
                        showCents: showCents,
                        currencySymbol: currencySymbol,
                        currency: currency,
                        swapTimeLabel: swapTimeLabel,
                        future: false,
                        showExpenseOrIncomeSign: showExpenseOrIncomeSign
                    )
                    .swipeToDelete(manager: transactionManager)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .onAppear {
            DispatchQueue.main.async {
                totalSpent = transactionSpendTotal
            }
        }
        .onChange(of: date) { _, _ in
            DispatchQueue.main.async {
                totalSpent = transactionSpendTotal
            }
        }
        // The ledger can change while this view stays alive (add from the
        // detail screen); recompute instead of showing a stale header.
        .onChange(of: transactions.map(\.spendBaseAmount)) { _, _ in
            totalSpent = transactionSpendTotal
        }
        .frame(maxHeight: .infinity)
    }

    /// Net of refunds, which is what the budget card subtracts.
    private var transactionSpendTotal: Double {
        transactions.reduce(0.0) { $0 + $1.spendBaseAmount }
    }

    init(category: CategoryModel?, day: Date, totalSpent: Binding<Double>) {
        date = day
        let now = Date.now
        let past = Date.distantPast
        let future = Date.distantFuture

        if let unwrappedCategory = category {
            let categoryId = unwrappedCategory.id
            // Refund rows belong in the list too: they explain why the total
            // is lower than the receipts show.
            _transactions = Query(filter: #Predicate<TransactionModel> {
                (($0.day ?? past) == day && !$0.income && !$0.adjustment && !$0.reimbursable
                    && ($0.date ?? future) <= now && $0.category?.id == categoryId)
                    || (($0.day ?? past) == day && $0.refundOf != nil
                    && ($0.date ?? future) <= now && $0.category?.id == categoryId)
            }, sort: [SortDescriptor(\.date, order: .reverse)])
        } else {
            _transactions = Query(filter: #Predicate<TransactionModel> {
                (($0.day ?? past) == day && !$0.income && !$0.adjustment && !$0.reimbursable
                    && ($0.date ?? future) <= now)
                    || (($0.day ?? past) == day && $0.refundOf != nil
                    && ($0.date ?? future) <= now)
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

    /// Net of refunds, which is what the budget card subtracts.
    private var transactionSpendTotal: Double {
        transactions.reduce(0.0) { $0 + $1.spendBaseAmount }
    }

    private func dayTotal(_ dayTransactions: [TransactionModel]) -> Double {
        // Cross-account totals are read in the base currency, the same as the
        // budget card and the insights screen. `signedBaseAmount` carries the
        // sign for income, spend and refund rows alike.
        dayTransactions.reduce(0.0) { $0 + $1.signedBaseAmount }
    }

    private func dayTotalString(_ total: Double) -> String {
        Money.format(total, currencyCode: currency, showsCents: showCents, plus: total >= 0)
    }

    private func dayHeader(_ entry: (day: Date, transactions: [TransactionModel])) -> some View {
        let total = dayTotal(entry.transactions)
        let dateText = dateConverter(date: entry.day).uppercased()
        let totalString = abs(total).formatted(.number.precision(.fractionLength(2)))

        return VStack(spacing: 4) {
            HStack {
                Text(dateText)
                Spacer()
                Text(dayTotalString(total))
                    .layoutPriority(1)
            }
            .font(.callout.weight(.semibold))
            .foregroundStyle(Color.SubtitleText)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(String
                .appFormatted("%@%@ was spent %@", currencySymbol, totalString,
                    dateConverterAccessibilityLabel(date: entry.day)))

            Line()
                .stroke(Color.Outline, style: StrokeStyle(lineWidth: 1.3, lineCap: .round))
        }
        .padding(.horizontal, 10)
        .padding(.top, 10)
        .textCase(nil)
    }

    @Environment(OverallTransactionManager.self) private var transactionManager

    var body: some View {
        List {
            if transactions.count == 0 {
                NoResultsView(fullscreen: false)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }

            ForEach(groupedByDay, id: \.day) { entry in
                Section {
                    ForEach(entry.transactions, id: \.id) { transaction in
                        SingleTransactionView(
                            transaction: transaction,
                            showCents: showCents,
                            currencySymbol: currencySymbol,
                            currency: currency,
                            swapTimeLabel: swapTimeLabel,
                            future: false,
                            showExpenseOrIncomeSign: showExpenseOrIncomeSign
                        )
                        .swipeToDelete(manager: transactionManager)
                    }
                } header: {
                    dayHeader(entry)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .onAppear {
            totalSpent = transactionSpendTotal
        }
        .onChange(of: date) { _, _ in
            totalSpent = transactionSpendTotal
        }
        .onChange(of: transactions.map(\.spendBaseAmount)) { _, _ in
            totalSpent = transactionSpendTotal
        }
    }

    /// `type` arrives as `budget.type - 1` (1 = week, 2 = month, 3 = year);
    /// day budgets use `FilteredCategoryDayBudgetView` instead.
    init(category: CategoryModel? = nil, startDate: Date, totalSpent: Binding<Double>, type: Int) {
        date = startDate

        let calendar = AppPeriod.configuredCalendar(
            firstWeekday: UserDefaults.appGroup.integer(forKey: "firstWeekday"))

        // The full period that starts at `startDate`, clipped to now. The old
        // code compared the start with today using the wrong granularity
        // (week/month/year shifted by one) and fell back to a date-only end,
        // so a current period either included planned rows or stopped early.
        let component: Calendar.Component
        let step: Int
        switch type {
        case 1: component = .day; step = 7
        case 2: component = .month; step = 1
        default: component = .year; step = 1
        }
        let periodEnd = calendar.date(byAdding: component, value: step, to: startDate) ?? .now
        let endDate = min(periodEnd, .now)

        let past = Date.distantPast
        let future = Date.distantFuture

        if let unwrappedCategory = category {
            let categoryId = unwrappedCategory.id
            _transactions = Query(filter: #Predicate<TransactionModel> {
                ((!$0.income && !$0.adjustment && !$0.reimbursable)
                    && ($0.date ?? past) >= startDate && ($0.date ?? future) < endDate
                    && $0.category?.id == categoryId)
                    || ($0.refundOf != nil
                    && ($0.date ?? past) >= startDate && ($0.date ?? future) < endDate
                    && $0.category?.id == categoryId)
            })
        } else {
            _transactions = Query(filter: #Predicate<TransactionModel> {
                ((!$0.income && !$0.adjustment && !$0.reimbursable)
                    && ($0.date ?? past) >= startDate && ($0.date ?? future) < endDate)
                    || ($0.refundOf != nil
                    && ($0.date ?? past) >= startDate && ($0.date ?? future) < endDate)
            })
        }

        _totalSpent = totalSpent
    }
}

/// Native swipe-to-delete for a ledger row inside a `List`.
private extension SingleTransactionView {
    func swipeToDelete(manager: OverallTransactionManager) -> some View {
        self
            .listRowInsets(EdgeInsets())
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                Button(String.appLocalized("Delete"), role: .destructive) {
                    manager.toDelete = transaction
                    manager.future = false
                    manager.showPopup = true
                }
            }
    }
}
