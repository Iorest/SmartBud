import Foundation
import SwiftData
import SwiftUI

struct BackgroundBlurView: UIViewRepresentable {
    func makeUIView(context _: Context) -> UIView {
        let view = UIView()
        DispatchQueue.main.async {
            view.superview?.superview?.backgroundColor = .clear
        }
        return view
    }

    func updateUIView(_: UIView, context _: Context) {}
}

struct FilteredRecurringView: View {
    @Query private var transactions: [TransactionModel]

    var displayedTransactions: [TransactionModel] {
        let now = Date.now
        return transactions.filter { $0.onceRecurring && ($0.date ?? .distantPast) <= now }
    }

    var body: some View {
        VStack(spacing: 30) {
            if displayedTransactions.count == 0 {
                NoResultsView(fullscreen: true)
            }

            ListView(transactions: displayedTransactions)
        }
        .frame(maxHeight: .infinity)
    }

    init() {
        _transactions = Query(
            filter: #Predicate<TransactionModel> { $0.onceRecurring == true },
            sort: [
                SortDescriptor(\TransactionModel.day, order: .reverse),
                SortDescriptor(\TransactionModel.date, order: .reverse),
                SortDescriptor(\TransactionModel.note, order: .reverse)
            ]
        )
    }
}

struct FilteredTypeView: View {
    @Query private var transactions: [TransactionModel]

    var income: Bool

    var displayedTransactions: [TransactionModel] {
        let now = Date.now
        return transactions.filter { $0.income == income && ($0.date ?? .distantPast) <= now }
    }

    var body: some View {
        VStack(spacing: 30) {
            if displayedTransactions.count == 0 {
                NoResultsView(fullscreen: true)
            }

            ListView(transactions: displayedTransactions)
        }
        .frame(maxHeight: .infinity)
    }

    init(income: Bool) {
        self.income = income
        _transactions = Query(
            filter: #Predicate<TransactionModel> { $0.income == income },
            sort: [
                SortDescriptor(\TransactionModel.day, order: .reverse),
                SortDescriptor(\TransactionModel.date, order: .reverse)
            ]
        )
    }
}

struct FilteredCategoryView: View {
    @Query private var transactions: [TransactionModel]

    var category: CategoryModel?

    var displayedTransactions: [TransactionModel] {
        let now = Date.now
        return transactions.filter { ($0.date ?? .distantPast) <= now }
    }

    var body: some View {
        VStack(spacing: 30) {
            if displayedTransactions.count == 0 || category == nil {
                NoResultsView(fullscreen: true)
            } else {
                ListView(transactions: displayedTransactions)
            }
        }
        .frame(maxHeight: .infinity)
    }

    init(category: CategoryModel?) {
        if let unwrappedCategory = category {
            let categoryId = unwrappedCategory.id
            _transactions = Query(
                filter: #Predicate<TransactionModel> { $0.category?.id == categoryId },
                sort: [
                    SortDescriptor(\TransactionModel.day, order: .reverse),
                    SortDescriptor(\TransactionModel.date, order: .reverse)
                ]
            )
        } else {
            _transactions = Query(sort: [
                SortDescriptor(\TransactionModel.day, order: .reverse),
                SortDescriptor(\TransactionModel.date, order: .reverse)
            ])
        }

        self.category = category
    }
}

struct FilteredDateView: View {
    @Query private var transactions: [TransactionModel]

    var date: Date

    @AppStorage("currency", store: .appGroup) var currency: String = Locale.current.currency?.identifier ?? "USD"
    var currencySymbol: String {
        return Locale.appCurrencySymbol(forCurrencyCode: currency)
    }

    @AppStorage("swapTimeLabel", store: .appGroup) var swapTimeLabel: Bool = false

    @AppStorage("showCents", store: .appGroup) var showCents: Bool = true

    @AppStorage("showExpenseOrIncomeSign", store: .appGroup)
    var showExpenseOrIncomeSign: Bool = true

    var displayedTransactions: [TransactionModel] {
        let now = Date.now
        return transactions.filter { $0.day == date && ($0.date ?? .distantPast) <= now }
    }

    var body: some View {
        VStack(spacing: 0) {
            if displayedTransactions.count == 0 {
                NoResultsView(fullscreen: true)
            }
            ForEach(displayedTransactions) { transaction in
                SingleTransactionView(transaction: transaction, showCents: showCents, currencySymbol: currencySymbol, currency: currency, swapTimeLabel: swapTimeLabel, future: false, showExpenseOrIncomeSign: showExpenseOrIncomeSign)
            }
        }
        .frame(maxHeight: .infinity)
    }

    init(date: Date) {
        self.date = date
        let past = Date.distantPast
        _transactions = Query(
            filter: #Predicate<TransactionModel> { ($0.day ?? past) == date },
            sort: [SortDescriptor(\TransactionModel.date, order: .reverse)]
        )
    }
}

struct NoResultsView: View {
    let fullscreen: Bool

    var body: some View {
        if fullscreen {
            VStack(spacing: 12) {
                Spacer()

                Image(systemName: "tray.full.fill")
                    .font(.system(.largeTitle, design: .rounded))
                    .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
//                    .font(.system(size: 38, weight: .regular, design: .rounded))
                    .foregroundStyle(Color.SubtitleText)

                Text(String.appLocalized("No entries found."))
                    .font(.system(.title3, design: .rounded).weight(.medium))
                    .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
//                    .font(.system(size: 21, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.SubtitleText)

                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .frame(height: ScreenSize.height * 0.7)
            .opacity(0.7)
        } else {
            VStack(spacing: 12) {
                Spacer()

                //            Text("📭️")
                //                .font(.system(size: 45))
                //                .padding(.bottom, 9)
                //                .accessibility(hidden: true)

                Image(systemName: "tray.full.fill")
                    .font(.system(size: 38, weight: .regular, design: .rounded))
                    .foregroundStyle(Color.SubtitleText)

                Text(String.appLocalized("No entries found."))
                    .font(.system(size: 21, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.SubtitleText)

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .opacity(0.7)
            .padding(.top, 50)
        }
    }
}

