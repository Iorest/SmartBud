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
            .accessibilityIdentifier(AccessibilityID.logTypeFilter)
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

    @Binding var showingDate: Date

    /// Same bucket definition as the list filter, so the label and the rows
    /// can never describe different weeks.
    private var calendar: Calendar {
        AppPeriod.configuredCalendar(
            firstWeekday: UserDefaults.appGroup.integer(forKey: "firstWeekday"))
    }

    private var currentStart: Date {
        AppPeriod.weekRange(containing: .now, calendar: calendar).start
    }

    private var oldestStart: Date? {
        guard let oldest = transactions.first?.day else { return nil }
        return AppPeriod.weekRange(containing: oldest, calendar: calendar).start
    }

    private var canGoBack: Bool {
        showingDate > (oldestStart ?? currentStart)
    }

    private var canGoForward: Bool {
        showingDate < currentStart
    }

    private var dateString: String {
        let end = calendar.date(byAdding: .day, value: 6, to: showingDate) ?? showingDate
        let style = Date.FormatStyle(locale: .appLocale).month(.abbreviated).day()
        guard calendar.component(.year, from: showingDate)
                == calendar.component(.year, from: .now) else {
            let full = Date.FormatStyle(locale: .appLocale).year().month(.abbreviated).day()
            return showingDate.formatted(full) + " – " + end.formatted(full)
        }
        return showingDate.formatted(style) + " – " + end.formatted(style)
    }

    var body: some View {
        HStack {
            StepperButtonView(left: true, disabled: !canGoBack) {
                showingDate = calendar.date(byAdding: .day, value: -7, to: showingDate)
                    ?? showingDate
            }
            .accessibilityLabel(Text(String.appLocalized("previous week")))

            Spacer()

            Text(dateString)
                .font(.headline)
                .accessibilityLabel(dateString)

            Spacer()

            StepperButtonView(left: false, disabled: !canGoForward) {
                showingDate = calendar.date(byAdding: .day, value: 7, to: showingDate)
                    ?? showingDate
            }
            .accessibilityLabel(Text(String.appLocalized("next week")))
        }
        .frame(maxWidth: .infinity)
        .onAppear { showingDate = currentStart }
    }

    init(showingDate: Binding<Date>) {
        self._showingDate = showingDate
    }
}
