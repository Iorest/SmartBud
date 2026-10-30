//
//  NewBudgetView.swift
//  smartbud
//
//  Created by Iorest on 15/7/23.
//

import SwiftUI
import SwiftData

struct InstructionHeadings {
    let title: String
    let subtitle: String
}

struct BrandNewBudgetView: View {
    @Query private var categories: [CategoryModel]

    @AppStorage("firstWeekday", store: .appGroup) var firstWeekday: Int = 1
    @AppStorage("firstDayOfMonth", store: .appGroup) var firstDayOfMonth: Int = 1

    @Environment(BudgetViewModel.self) var budgetVM

    @Environment(\.dismiss) var dismiss

    @State var progress = 1

    @State var showToast: Bool = false
    @State var toastMessage: String = String.appLocalized("Missing Category")

    // sensory feedback triggers
    @State var errorHaptic = 0
    @State var lightHaptic = 0

    // stage one (ignore if editing), overall budget or category budget
    @State var categoryBudget: Bool = false
    var overallBudgetCreated: Bool

    // stage two (ignore if overall budget or editing)
    @State var selectedCategory: CategoryModel?
    @State var showingCategoryView = false

    // stage 3
    @State var budgetTimeFrame = BudgetTimeFrame.week

    // stage 4
    @State var chosenDayWeek = 1
    @State var chosenDayMonth = 1
    @State var chosenDayYear = Date.now

    var oneYearAgo: Date {
        return Calendar.current.date(byAdding: .year, value: -1, to: Date.now)!
    }

    // stage 5

    @AppStorage("numberEntryType", store: .appGroup) var numberEntryType: Int = 1
    @AppStorage("haptics", store: .appGroup) var hapticType: Int = 1

    @State var padVM = NumberPadViewModel(numberEntryType: 1, hapticType: 1)

    @AppStorage("currency", store: .appGroup) var currency: String = Locale.current.currency?.identifier ?? "USD"
    var currencySymbol: String {
        return Locale.appCurrencySymbol(forCurrencyCode: currency)
    }

    var amountPerDayString: String {
        let numberFormatter = NumberFormatter()
        numberFormatter.locale = Locale.appLocale
        numberFormatter.numberStyle = .currency
        numberFormatter.currencyCode = currency

        let average: Double

        // Use the same period maths as the rest of the app: a month that starts
        // on the 15th runs 30/31 days, so a flat /30 makes the hint disagree
        // with the budget's own date range.
        let calendar = Calendar.current
        switch budgetTimeFrame {
        case .week:
            average = padVM.price / 7
        case .month:
            let range = AppPeriod.monthRange(containing: .now,
                                             startDay: firstDayOfMonth,
                                             calendar: calendar)
            average = padVM.price / Double(AppPeriod.dayCount(in: range, calendar: calendar))
        default:
            let range = AppPeriod.yearRange(containing: .now, calendar: calendar)
            average = padVM.price / Double(AppPeriod.dayCount(in: range, calendar: calendar))
        }

        numberFormatter.maximumFractionDigits = 0

        return "~\(numberFormatter.string(from: NSNumber(value: average)) ?? "$0") \(String.appLocalized("/day"))"
    }

    // editMode
    let toEditBudget: BudgetModel?
    let toEditMainBudget: MainBudgetModel?
    var editMode: Bool {
        toEditBudget != nil || toEditMainBudget != nil
    }

    @Namespace var animation

    var labelHeight: CGFloat {
        progress == 1 ? 120 : 130
    }

    var showBackButton: Bool {
        progress > 1
    }

    var instructions: [InstructionHeadings] {
        [
            InstructionHeadings(
                title: String.appLocalized("Indicate budget type"),
                subtitle: String
                    .appLocalized("Pick the scope, period and start day. You can change all of this later.")),
            InstructionHeadings(
                title: String.appLocalized("Set budget amount"),
                subtitle: String.appLocalized("Try your best to stay under this limit! "
                     + "Also, feel free to change this in the future."))
        ]
    }

    // MARK: - Page 1: details

    private var weekdaySymbols: [String] {
        var calendar = Calendar.current
        calendar.locale = Locale.appLocale
        return calendar.weekdaySymbols
    }

    /// Categories the picker offers: no budget yet, plus the category this
    /// editor is editing (it already owns one, and hiding it would blank the
    /// selection and make the original category impossible to re-pick).
    private var selectableCategories: [CategoryModel] {
        categories.filter { $0.budget == nil || $0.budget?.id == toEditBudget?.id }
    }

    var budgetDetails: some View {
        Form {
            Section {
                Picker(String.appLocalized("Budget type"), selection: $categoryBudget) {
                    Text(String.appLocalized("Overall Budget")).tag(false)
                    Text(String.appLocalized("Category Budget")).tag(true)
                }
                .pickerStyle(.segmented)
                .disabled(editMode)
            }

            if categoryBudget {
                Section(String.appLocalized("Category")) {
                    if selectableCategories.isEmpty {
                        Button {
                            showingCategoryView = true
                        } label: {
                            Label(String.appLocalized("Add a category"), systemImage: "plus")
                        }
                    } else {
                        Picker(String.appLocalized("Select a category"), selection: $selectedCategory) {
                            Text(String.appLocalized("Select")).tag(CategoryModel?.none)
                            ForEach(selectableCategories) { category in
                                Text("\(category.wrappedEmoji) \(category.wrappedName)")
                                    .tag(Optional(category))
                            }
                        }
                        .labelsHidden()
                    }
                }
            }

            Section {
                Picker(String.appLocalized("Time frame"), selection: $budgetTimeFrame) {
                    ForEach(BudgetTimeFrame.allCases, id: \.self) { time in
                        Text(LocalizedStringKey(time.rawValue)).tag(time)
                    }
                }
            }

            startDaySection
        }
        .scrollContentBackground(.hidden)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var startDaySection: some View {
        switch budgetTimeFrame {
        case .day:
            EmptyView()
        case .week:
            Section {
                Picker(String.appLocalized("Start day"), selection: $chosenDayWeek) {
                    ForEach(1...7, id: \.self) { index in
                        Text(weekdaySymbols[index - 1]).tag(index)
                    }
                }
            }
        case .month:
            Section {
                Picker(String.appLocalized("Start day"), selection: $chosenDayMonth) {
                    ForEach(1..<29, id: \.self) { day in
                        Text(day == 1
                             ? String.appLocalized("Start of month")
                             : String(format: String.appLocalized("%@ of month"), "\(day)"))
                            .tag(day)
                    }
                }
            }
        case .year:
            Section {
                DatePicker(
                    String.appLocalized("Start date"),
                    selection: $chosenDayYear,
                    in: oneYearAgo ... Date.now,
                    displayedComponents: .date
                )
            }
        }
    }

    func continueToAmount() {
        if categoryBudget && selectedCategory == nil {
            showToast = true
            toastMessage = String.appLocalized("Missing Category")
            errorHaptic &+= 1
            return
        }

        lightHaptic &+= 1
        withAnimation(.easeInOut(duration: 0.2)) {
            progress = 5
        }
    }

    // MARK: - Page 2: amount

    var amountPage: some View {
        VStack(spacing: 10) {
            NumberPadTextView(viewModel: padVM, currencySymbol: currencySymbol)

            if budgetTimeFrame != .day && padVM.price > 0 {
                Text(amountPerDayString)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.SubtitleText)
                    .padding(4)
                    .padding(.horizontal, 7)
                    .background(Color.SecondaryBackground, in: Capsule())
            }

            Spacer()

            NumberPad(viewModel: padVM) {
                submit()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Seeds the picker state from an existing budget. `BudgetModel` and
    /// `MainBudgetModel` store the same `type` start-date pair, so both edit
    /// paths share one mapping.
    func applyEditorState(type: Int, startDate: Date, amount: Double) {
        switch type {
        case 1:
            budgetTimeFrame = .day
        case 2:
            budgetTimeFrame = .week
            chosenDayWeek = Calendar.current.dateComponents([.weekday], from: startDate).weekday ?? firstWeekday
        case 3:
            budgetTimeFrame = .month
            chosenDayMonth = Calendar.current.dateComponents([.day], from: startDate).day ?? firstDayOfMonth
        case 4:
            budgetTimeFrame = .year
            chosenDayYear = startDate
        default:
            budgetTimeFrame = .week
        }

        padVM.price = amount
        if amount.truncatingRemainder(dividingBy: 1) > 0 && numberEntryType == 2 {
            padVM.isEditingDecimal = true
        }
    }

    func getBudgetTypeInteger(_ budget: BudgetTimeFrame) -> Int {
        switch budget {
        case .day:
            return 1
        case .week:
            return 2
        case .month:
            return 3
        case .year:
            return 4
        }
    }

    init(overallBudgetCreated: Bool, toEditBudget: BudgetModel? = nil, toEditMainBudget: MainBudgetModel? = nil) {
        if toEditBudget != nil {
            self.overallBudgetCreated = overallBudgetCreated
            _progress = State(initialValue: 1)
            _categoryBudget = State(initialValue: true)
        } else if toEditMainBudget != nil {
            self.overallBudgetCreated = overallBudgetCreated
            _progress = State(initialValue: 1)
            _categoryBudget = State(initialValue: false)
        } else {
            if overallBudgetCreated {
                self.overallBudgetCreated = true
                _progress = State(initialValue: 1)
                _categoryBudget = State(initialValue: true)
                } else {
                self.overallBudgetCreated = false
                }
        }

        self.toEditBudget = toEditBudget
        self.toEditMainBudget = toEditMainBudget

        // Fetch every expense category; the picker filters out the ones that
        // already have a budget, except the one being edited (that category
        // always owns a budget, so a `budget == nil` predicate hid the
        // current selection and left the row blank).
        _categories = Query(
            filter: #Predicate<CategoryModel> { $0.income == false },
            sort: [SortDescriptor(\.order)]
        )
    }

}

extension BrandNewBudgetView {

}
