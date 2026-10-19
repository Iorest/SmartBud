import Foundation
import SwiftData
import SwiftUI

struct TransactionsList: View {
    var filter: FilterType
    var category: CategoryModel?
    var date: Date
    var week: Date
    var month: Date
    var income: Bool

    @AppStorage("showUpcomingTransactions", store: .appGroup) var showUpcoming: Bool = true
    @AppStorage("showUpcomingTransactionsWhenUpcoming", store: .appGroup) var showSoon: Bool = false

    @Query private var transactions: [TransactionModel]

    var body: some View {
        VStack {
            if (filter == .all && showUpcoming) || filter == .upcoming {
                FutureListView(filterMode: filter == .upcoming, limitedMode: showSoon)
                    .padding(.top, 10)
            }

            switch filter {
            case .all:
                ListView(transactions: transactions)
            case .category:
                FilteredCategoryView(category: category)
            case .day:
                FilteredDateView(date: date)
            case .week:
                FilteredInsightsView(startDate: week, type: 1)
            case .month:
                FilteredInsightsView(startDate: month, type: 2)
            case .recurring:
                FilteredRecurringView()
            case .type:
                FilteredTypeView(income: income)
            case .upcoming:
                EmptyView()
            }
        }
    }

    init(filter: FilterType, category: CategoryModel?, date: Date, week: Date, month: Date, income: Bool) {
        self.filter = filter
        self.category = category
        self.date = date
        self.week = week
        self.month = month
        self.income = income
        let now = Date.now
        let past = Date.distantPast
        _transactions = Query(
            filter: #Predicate<TransactionModel> { ($0.date ?? past) <= now },
            sort: [
                SortDescriptor(\TransactionModel.day, order: .reverse),
                SortDescriptor(\TransactionModel.date, order: .reverse),
                SortDescriptor(\TransactionModel.note)
            ]
        )
    }
}

struct ListView: View {
    var transactions: [TransactionModel]

    @AppStorage("showCents", store: .appGroup) var showCents: Bool = true

    @AppStorage("currency", store: .appGroup) var currency: String = Locale.current.currency?.identifier ?? "USD"
    var currencySymbol: String {
        return Locale.appCurrencySymbol(forCurrencyCode: currency)
    }
    
    @AppStorage("showExpenseOrIncomeSign", store: .appGroup)
    var showExpenseOrIncomeSign: Bool = true

    @AppStorage("swapTimeLabel", store: .appGroup) var swapTimeLabel: Bool = false

    @Environment(OverallToastPresenter.self) var toastPresenter

    var groupedByDay: [(day: Date, transactions: [TransactionModel])] {
        let grouped = Dictionary(grouping: transactions) { $0.day ?? Date.now }
        return grouped.keys.sorted(by: >).map { day in
            (day, grouped[day]!.sorted { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) })
        }
    }

    var body: some View {
        LazyVStack(spacing: 0) {
            ForEach(groupedByDay, id: \.day) { day in
                let filtered = filterOutDupes(dayTransactions: day.transactions)
                let dateText = dateConverter(date: day.day).uppercased()
                let totalString = filtered.total.formatted(.number.precision(.fractionLength(2)))

                VStack(spacing: 0) {
                    VStack(spacing: 4) {
                        HStack {
                            Text(dateText)
                            Spacer()

                            Text(filtered.string)
                                .layoutPriority(1)
                        }
                        .font(.system(.callout, design: .rounded).weight(.semibold))
                        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
//                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.SubtitleText)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(String(localized: "\(currencySymbol)\(totalString) was spent \(dateConverterAccessibilityLabel(date: day.day))"))

                        Line()
                            .stroke(Color.Outline, style: StrokeStyle(lineWidth: 1.3, lineCap: .round))
                    }
                    .padding(.horizontal, 10)
                    .padding(.top, 10)

                    ForEach(filtered.transactions, id: \.id) { transaction in
                        SingleTransactionView(transaction: transaction, showCents: showCents, currencySymbol: currencySymbol, currency: currency, swapTimeLabel: swapTimeLabel, future: false, showExpenseOrIncomeSign: showExpenseOrIncomeSign)
                    }
                }
                .contentShape(RoundedRectangle(cornerRadius: GlassRadius.chip))
                .contextMenu {
                        Button {
                            guard let image = ImageRenderer(content: SingleDayPhotoView(amountText: filtered.string, dateText: dateText, transactions: filtered.transactions, showCents: showCents, currencySymbol: currencySymbol, currency: currency, swapTimeLabel: swapTimeLabel, future: false)).uiImage else {
                                return
                            }

                            UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)

                            self.toastPresenter.showToast.toggle()
                        } label: {
                            Label(String.appLocalized("Save as Photo"), systemImage: "square.and.arrow.up")
                        }
                }
                .padding(.bottom, 18)
            }
        }
    }

    func filterOutDupes(dayTransactions: [TransactionModel]) -> (transactions: [TransactionModel], string: String, total: Double) {
        var seen = [TransactionModel]()
        let filtered = dayTransactions.filter { entity -> Bool in

            if seen.contains(where: { $0.id == entity.id }) {
                return false
            } else {
                seen.append(entity)
                return true
            }
        }

        let numberFormatter = NumberFormatter()
        numberFormatter.locale = Locale.appLocale
        numberFormatter.numberStyle = .currency
        numberFormatter.currencyCode = currency

        if showCents {
            numberFormatter.maximumFractionDigits = 2
        } else {
            numberFormatter.maximumFractionDigits = 0
        }

        let total = dayTotal(dayTransaction: filtered)

        let text: String

        if total >= 0 {
            text = "+" + (numberFormatter.string(from: NSNumber(value: total)) ?? "$0")
        } else {
            text = (numberFormatter.string(from: NSNumber(value: total)) ?? "$0")
        }

        return (filtered, text, total)
    }
}

struct FutureListView: View {
    @Query private var fetchedResults: [TransactionModel]
    var filterMode: Bool
    var limitedMode: Bool

    var transactions: [TransactionModel] {
        if limitedMode {
            let calendar = Calendar.current

            let startOfToday = calendar.startOfDay(for: Date.now)
            let twoWeeksFromStartOfToday = calendar.date(byAdding: .weekOfYear, value: 2, to: startOfToday)!

            let holding = fetchedResults.filter {
                let date = $0.wrappedDate > Date.now ? $0.wrappedDate : $0.nextTransactionDate

                return date < twoWeeksFromStartOfToday
            }

            return holding.sorted { itemA, itemB in
                let date1 = itemA.wrappedDate > Date.now ? itemA.wrappedDate : itemA.nextTransactionDate
                let date2 = itemB.wrappedDate > Date.now ? itemB.wrappedDate : itemB.nextTransactionDate

                return date1 > date2
            }

        } else {
            return fetchedResults.sorted { itemA, itemB in
                let date1 = itemA.wrappedDate > Date.now ? itemA.wrappedDate : itemA.nextTransactionDate
                let date2 = itemB.wrappedDate > Date.now ? itemB.wrappedDate : itemB.nextTransactionDate

                return date1 > date2
            }
        }
    }

    @AppStorage("showCents", store: .appGroup) var showCents: Bool = true

    @AppStorage("currency", store: .appGroup) var currency: String = Locale.current.currency?.identifier ?? "USD"
    var currencySymbol: String {
        return Locale.appCurrencySymbol(forCurrencyCode: currency)
    }
    
    @AppStorage("showExpenseOrIncomeSign", store: .appGroup)
    var showExpenseOrIncomeSign: Bool = true

    @AppStorage("swapTimeLabel", store: .appGroup) var swapTimeLabel: Bool = false

    var totalString: String {
        let numberFormatter = NumberFormatter()
        numberFormatter.locale = Locale.appLocale
        numberFormatter.numberStyle = .currency
        numberFormatter.currencyCode = currency

        if showCents {
            numberFormatter.maximumFractionDigits = 2
        } else {
            numberFormatter.maximumFractionDigits = 0
        }

        var total = 0.0

        transactions.forEach { transaction in
            if transaction.income {
                total += transaction.amount
            } else {
                total -= transaction.amount
            }
        }

        if total >= 0 {
            return "+" + (numberFormatter.string(from: NSNumber(value: total)) ?? "$0")
        } else {
            return numberFormatter.string(from: NSNumber(value: total)) ?? "$0"
        }
    }

    var body: some View {
        if !transactions.isEmpty {
            VStack(spacing: 0) {
                VStack(spacing: 4) {
                    HStack {
                        Text(String.appLocalized("UPCOMING"))
                        Spacer()

                        Text(totalString)
                    }
                    .font(.system(.callout, design: .rounded).weight(.semibold))
                    .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
//                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.SubtitleText)
                    .accessibilityElement(children: .ignore)

                    Line()
                        .stroke(Color.Outline, style: StrokeStyle(lineWidth: 1.3, lineCap: .round))
                }
                .padding(.horizontal, 10)

                ForEach(transactions) { transaction in
                    SingleTransactionView(transaction: transaction, showCents: showCents, currencySymbol: currencySymbol, currency: currency, swapTimeLabel: swapTimeLabel, future: true, showExpenseOrIncomeSign: showExpenseOrIncomeSign)
                }
            }
            .padding(.bottom, 18)
        } else if transactions.isEmpty && filterMode {
            NoResultsView(fullscreen: true)
        } else {
            EmptyView()
        }
    }

    init(filterMode: Bool, limitedMode: Bool) {
        let now = Date.now
        let past = Date.distantPast
        _fetchedResults = Query(filter: #Predicate<TransactionModel> {
            $0.recurringType > 0 || (($0.date ?? past) > now)
        })

        self.filterMode = filterMode
        self.limitedMode = limitedMode
    }
}

