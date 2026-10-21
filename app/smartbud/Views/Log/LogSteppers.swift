import Foundation
import SwiftData
import SwiftUI

struct CategoryStepperView: View {
    @Binding var categoryFilter: CategoryModel?
    @State var income = false

    @Query(filter: #Predicate<CategoryModel> { $0.income == false },
        sort: [SortDescriptor(\CategoryModel.order)]) private var expenseCategories: [CategoryModel]
    @Query(filter: #Predicate<CategoryModel> { $0.income == true },
        sort: [SortDescriptor(\CategoryModel.order)]) private var incomeCategories: [CategoryModel]

    var categories: [CategoryModel] {
        income ? incomeCategories : expenseCategories
    }

    var body: some View {
        HStack(spacing: 8) {
            if income {
                Image(systemName: "plus")
                    .font(.body.weight(.semibold))

                    .foregroundStyle(Color.IncomeGreen)
                    .padding(7)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .aspectRatio(1.0, contentMode: .fit)
                    .background(
                        Color.IncomeGreen.opacity(0.23),
                        in: RoundedRectangle(cornerRadius: SBRadius.chip, style: .continuous)
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if expenseCategories.isEmpty {
                            return
                        } else {
                            income = false
                            categoryFilter = expenseCategories[0]
                        }
                    }
            } else {
                Image(systemName: "minus")
                    .font(.body.weight(.semibold))

                    .foregroundStyle(Color.AlertRed)
                    .padding(7)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .aspectRatio(1.0, contentMode: .fit)
                    .background(
                        Color.AlertRed.opacity(0.23),
                        in: RoundedRectangle(cornerRadius: SBRadius.chip, style: .continuous)
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if incomeCategories.isEmpty {
                            return
                        } else {
                            income = true
                            categoryFilter = incomeCategories[0]
                        }
                    }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                ScrollViewReader { value in
                    HStack(spacing: 8) {
                        ForEach(categories, id: \.self) { item in
                            HStack(spacing: 5) {
                                Text(item.wrappedEmoji)
                                    .font(.footnote.weight(.medium))

                                Text(item.wrappedName)
                                    .font(.body.weight(.medium))

                            }
                            .id(item.id)
                            .padding(.horizontal, 11)
                            .padding(.vertical, 7)
                            .fixedSize(horizontal: false, vertical: true)
                            .foregroundStyle(
                                categoryFilter == item ? Color(hex: item.wrappedColour) : Color.PrimaryText
                            )
                            .background(
                                getBackground(category: item),
                                in: RoundedRectangle(cornerRadius: SBRadius.chip, style: .continuous)
                            )
                            .overlay {
                                if categoryFilter != item {
                                    RoundedRectangle(cornerRadius: SBRadius.chip, style: .continuous)
                                        .strokeBorder(Color.Outline,
                                                      style: StrokeStyle(lineWidth: 1.5))
                                }
                            }
                            .onTapGesture {
                                categoryFilter = item
                                withAnimation {
                                    value.scrollTo(item.id, anchor: .leading)
                                }
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 30)
        .onAppear {
            if categories.isEmpty {
                categoryFilter = nil
            } else {
                categoryFilter = categories[0]
            }
        }
        .onChange(of: income) { _, _ in
            if categories.isEmpty {
                categoryFilter = nil
            } else {
                categoryFilter = categories[0]
            }
        }
    }

    func getBackground(category: CategoryModel) -> Color {
        if category == categoryFilter {
            return Color(hex: category.wrappedColour).opacity(0.3)
        } else {
            return Color.PrimaryBackground
        }
    }

    init(categoryFilter: Binding<CategoryModel?>?) {
        _categoryFilter = categoryFilter ?? Binding.constant(nil)
    }
}

struct IncomeFilterToggleView: View {
    @Binding var income: Bool

    var body: some View {
        HStack {
            Picker(String.appLocalized("Type"), selection: $income) {
                Text(String.appLocalized("Expense")).tag(false)
                Text(String.appLocalized("Income")).tag(true)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(maxWidth: SBControlWidth.segment)

            Spacer(minLength: 0)
        }
    }
}

struct DateStepperView: View {
    @Query(sort: [SortDescriptor(\TransactionModel.day)]) private var transactions: [TransactionModel]

    @Binding var date: Date
    var endDate: Date {
        if transactions.isEmpty {
            return Date.now
        } else {
            return transactions[0].day ?? Date.now
        }
    }

    let currentDate = Calendar.current.date(bySettingHour: 0, minute: 0, second: 0, of: Date.now) ?? Date.now

    var dateString: String {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale.appLocale

        dateFormatter.setLocalizedDateFormatFromTemplate("yMMMd")

        return dateFormatter.string(from: date)
    }

    var body: some View {
        HStack {
            StepperButtonView(left: true, disabled: date <= endDate) {
                if date > endDate {
                    date = Calendar.current.date(byAdding: .day, value: -1, to: date) ?? Date.now
                }
            }
            .accessibilityLabel(Text(String.appLocalized("previous day")))

            Spacer()

            Text(dateString)
                .font(.headline)

                .accessibilityLabel(String.appFormatted("showing transactions on %@", dateString))

            Spacer()

            StepperButtonView(left: false, disabled: date >= currentDate) {
                if date < currentDate {
                    date = Calendar.current.date(byAdding: .day, value: 1, to: date) ?? Date.now
                }
            }
            .accessibilityLabel(Text(String.appLocalized("next day")))
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            date = currentDate
        }
    }
}

struct WeekStepperView: View {
    @Query(sort: [SortDescriptor(\TransactionModel.day)]) private var transactions: [TransactionModel]

    @Query private var transactionsReversed: [TransactionModel]

    @Binding var showingDate: Date
    var endDate: Date {
        if transactions.isEmpty {
            return Date.now
        } else {
            var calendar = Calendar(identifier: .gregorian)
            calendar.firstWeekday = UserDefaults.appGroup.integer(forKey: "firstWeekday")
            calendar.minimumDaysInFirstWeek = 4

            let date = transactions[0].day ?? Date.now

            let dateComponents = calendar.dateComponents([.weekOfYear, .yearForWeekOfYear], from: date)

            return calendar.date(from: dateComponents) ?? Date.now
        }
    }

    @State var startDate = Date.now

    var dateString: String {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale.appLocale

        dateFormatter.setLocalizedDateFormatFromTemplate("MMMd")

        let endComponents = DateComponents(day: 7, second: -1)
        let endWeekDate = Calendar.current.date(byAdding: endComponents, to: showingDate) ?? Date.now

        return dateFormatter.string(from: showingDate) + " - " + dateFormatter.string(from: endWeekDate)
    }

    var accessibilityDateString: String {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale.appLocale

        dateFormatter.setLocalizedDateFormatFromTemplate("MMMd")

        let endComponents = DateComponents(day: 7, second: -1)
        let endWeekDate = Calendar.current.date(byAdding: endComponents, to: showingDate) ?? Date.now

        return String.appFormatted(
            "showing transactions from %@ to %@",
            dateFormatter.string(from: showingDate),
            dateFormatter.string(from: endWeekDate)
        )
    }

    var body: some View {
        HStack {
            StepperButtonView(left: true, disabled: showingDate == endDate) {
                if showingDate > endDate {
                    showingDate = Calendar.current.date(byAdding: .day, value: -7, to: showingDate) ?? Date.now
                }
            }
            .accessibilityLabel(Text(String.appLocalized("previous week")))

            Spacer()

            Text(dateString)
                .font(.headline)
                .accessibilityLabel(accessibilityDateString)

            Spacer()

            StepperButtonView(left: false, disabled: showingDate == startDate) {
                if showingDate < startDate {
                    showingDate = Calendar.current.date(byAdding: .day, value: 7, to: showingDate) ?? Date.now
                }
            }
            .accessibilityLabel(Text(String.appLocalized("next week")))
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            var calendar = Calendar(identifier: .gregorian)

            calendar.firstWeekday = UserDefaults.appGroup.integer(forKey: "firstWeekday")
            calendar.minimumDaysInFirstWeek = 4

            let date = transactionsReversed.first?.day ?? Date.now

            let dateComponents = calendar.dateComponents([.weekOfYear, .yearForWeekOfYear], from: date)

            startDate = calendar.date(from: dateComponents) ?? Date.now

            showingDate = startDate
        }
    }

    init(showingDate: Binding<Date>) {
        self._showingDate = showingDate
        let now = Date.now
        let future = Date.distantFuture
        _transactionsReversed = Query(
            filter: #Predicate<TransactionModel> { ($0.date ?? future) < now },
            sort: [SortDescriptor(\TransactionModel.day, order: .reverse)]
        )
    }
}
