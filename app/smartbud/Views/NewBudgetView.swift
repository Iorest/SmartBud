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
    @State private var errorHaptic = 0
    @State private var lightHaptic = 0

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

    var timeFrameString: String {
        switch budgetTimeFrame {
        case .day:
            return String.appLocalized("day")
        case .week:
            return String.appLocalized("weekNewBudget")
        case .month:
            return String.appLocalized("monthNewBudget")
        case .year:
            return String.appLocalized("yearNewBudget")
        }
    }

    var oneYearAgo: Date {
        return Calendar.current.date(byAdding: .year, value: -1, to: Date.now)!
    }

    // stage 5

    @AppStorage("numberEntryType", store: .appGroup) var numberEntryType: Int = 1

    @State private var padVM = NumberPadViewModel(numberEntryType: 1, hapticType: 1)

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

        if budgetTimeFrame == .week {
            average = padVM.price / 7
        } else if budgetTimeFrame == .month {
            average = padVM.price / 30
        } else {
            average = padVM.price / 365
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
                subtitle: String.appLocalized("Pick the scope, period and start day. You can change all of this later.")),
            InstructionHeadings(
                title: String.appLocalized("Set budget amount"),
                subtitle: String.appLocalized("Try your best to stay under this limit! Also, feel free to change this in the future."))
        ]
    }

    // MARK: - Page 1: details

    private var weekdaySymbols: [String] {
        var calendar = Calendar.current
        calendar.locale = Locale.appLocale
        return calendar.weekdaySymbols
    }

    @ViewBuilder
    private var budgetDetails: some View {
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
                    if categories.isEmpty {
                        Button {
                            showingCategoryView = true
                        } label: {
                            Label(String.appLocalized("Add a category"), systemImage: "plus")
                        }
                    } else {
                        Picker(String.appLocalized("Select a category"), selection: $selectedCategory) {
                            Text(String.appLocalized("Select")).tag(CategoryModel?.none)
                            ForEach(categories) { category in
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

    private func continueToAmount() {
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

    private var amountPage: some View {
        VStack(spacing: 10) {
            NumberPadTextView(vm: padVM, currencySymbol: currencySymbol)

            if budgetTimeFrame != .day && padVM.price > 0 {
                Text(amountPerDayString)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.SubtitleText)
                    .padding(4)
                    .padding(.horizontal, 7)
                    .background(Color.SecondaryBackground, in: Capsule())
            }

            Spacer()

            NumberPad(vm: padVM) {
                submit()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                    Button {
                        if showBackButton {
                            withAnimation(.interactiveSpring(response: 0.6, dampingFraction: 0.8, blendDuration: 0.8)) {
                                if progress > 1 {
                                    progress = 1
                                }
                            }
                        } else {
                            dismiss()
                        }
                    } label: {
                        Image(systemName: showBackButton ? "chevron.left" : "xmark")
                            .font(.callout.weight(.semibold))

                            .foregroundStyle(Color.SubtitleText)
                            .padding(8)
                            .background(Color.SecondaryBackground, in: Circle())
                    }
                    .contentTransition(.symbolEffect(.replace.downUp.wholeSymbol))

                Spacer()

                ProgressView(value: progress == 1 ? 0.5 : 1)
                    .frame(width: 72)
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay {
                if showToast {
                    HStack(spacing: 6.5) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.AlertRed)

                        Text(toastMessage)
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(Color.AlertRed)
                    }
                    .padding(8)
                    .background(Color.AlertRed.opacity(0.23), in: RoundedRectangle(cornerRadius: SBRadius.chip, style: .continuous))
                    .transition(AnyTransition.opacity.combined(with: .move(edge: .top)))
                    .frame(width: 250)
                }
            }
            .padding(.bottom, 50)
            .animation(.easeInOut, value: showBackButton)

            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(instructions[progress == 1 ? 0 : 1].title)
                        .foregroundStyle(Color.PrimaryText)
                        .font(.title2.weight(.semibold))

                    Spacer()
                }
                .frame(maxWidth: .infinity)

                Text(instructions[progress == 1 ? 0 : 1].subtitle)
                    .foregroundStyle(Color.SubtitleText)
                    .font(.body.weight(.medium))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: labelHeight, alignment: .top)

            if progress == 1 {
                budgetDetails
            } else {
                amountPage
            }

            if progress == 1 {
                Button {
                    continueToAmount()
                } label: {
                    Text(String.appLocalized("Continue"))
                        .font(.body.weight(.semibold))
                        .padding(.vertical, 13)
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(Color.LightIcon)
                        .background(Color.DarkBackground, in: RoundedRectangle(cornerRadius: SBRadius.card, style: .continuous))
                }
                .buttonStyle(BouncyButton(duration: 0.2, scale: 0.8))
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        
        .appBackground()
        .onAppear {
            // Sync the pad VM with the AppStorage flags on first appearance.
            // Subsequent changes are picked up by the `onChange` below.
            padVM.numberEntryType = numberEntryType
            if let edited = toEditBudget {
                selectedCategory = edited.category
                applyEditorState(type: edited.type, startDate: edited.startDate, amount: edited.amount)
            } else if let edited = toEditMainBudget {
                applyEditorState(type: edited.type, startDate: edited.startDate, amount: edited.amount)
            } else {
                chosenDayWeek = firstWeekday
                chosenDayMonth = firstDayOfMonth
            }
        }
        .sheet(isPresented: $showingCategoryView) {
                NewCategoryAlert(income: Binding.constant(false), bottomSpacers: false, budgetMode: true)
                    .presentationDetents([.medium, .large])
        }
        .animation(.easeOut(duration: 0.2), value: showToast)
        .onChange(of: numberEntryType) { _, new in
            padVM.numberEntryType = new
        }
        .onChange(of: showToast) { _, newValue in
            if newValue {
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(2))
                    showToast = false
                }
            }
        }
        .sensoryFeedback(.error, trigger: errorHaptic)
        .sensoryFeedback(.impact(weight: .light), trigger: lightHaptic)
    }

    func submit() {
        let amount = padVM.price
        if amount == 0 {
            errorHaptic &+= 1
            showToast = true
            toastMessage = String.appLocalized("Missing Amount")
            return
        }

        lightHaptic &+= 1

        let budgetType = getBudgetTypeInteger(budgetTimeFrame)
        let timeFrameInt: Int = {
            switch budgetTimeFrame {
            case .day: return 0
            case .week: return 1
            case .month: return 2
            case .year: return 3
            }
        }()
        let computedStart = budgetVM.computeStartDate(
            timeFrameRaw: timeFrameInt,
            chosenDayWeek: chosenDayWeek,
            chosenDayMonth: chosenDayMonth,
            chosenDayYear: chosenDayYear
        )
        let originalStart = toEditBudget?.startDate ?? toEditMainBudget?.startDate
        let originalType = toEditBudget?.type ?? toEditMainBudget?.type ?? budgetType
        let startDate = BudgetAnchor.startDate(
            original: originalStart,
            oldType: originalType,
            newType: budgetType,
            computed: computedStart
        )

        if let unwrappedEditedBudget = toEditBudget {
            let category = selectedCategory ?? unwrappedEditedBudget.category
            if let category {
                budgetVM.update(
                    unwrappedEditedBudget,
                    amount: amount,
                    startDate: startDate,
                    type: budgetType,
                    category: category
                )
            }

            padVM.submit()
            dismiss()

            return
        }

        if let unwrappedEditedMainBudget = toEditMainBudget {
            budgetVM.updateMain(
                unwrappedEditedMainBudget,
                amount: amount,
                startDate: startDate,
                type: budgetType
            )

            padVM.submit()
            dismiss()

            return
        }

        if categoryBudget {
            if let unwrappedCategory = selectedCategory {
                _ = budgetVM.create(amount: amount, startDate: startDate, type: budgetType, category: unwrappedCategory)
            }
        } else {
            _ = budgetVM.createMain(amount: amount, startDate: startDate, type: budgetType)
        }

        padVM.submit()
        dismiss()
    }

    /// Seeds the picker state from an existing budget. `BudgetModel` and
    /// `MainBudgetModel` store the same `type` start-date pair, so both edit
    /// paths share one mapping.
    private func applyEditorState(type: Int, startDate: Date, amount: Double) {
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

        _categories = Query(filter: #Predicate<CategoryModel> { $0.budget == nil && $0.income == false }, sort: [SortDescriptor(\.order)])
    }

}

