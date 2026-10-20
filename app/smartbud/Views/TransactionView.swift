//
//  TransactionView.swift
//  smartbud
//
//  Created by Iorest on 14/5/22.
//

import Foundation
import SwiftUI

struct TransactionView: View {
    @Environment(CategoryViewModel.self) var categoryVM
    @Environment(TransactionViewModel.self) var transactionVM

    @Environment(\.dismiss) var dismiss

    @Environment(\.colorScheme) var colorScheme
    var boldText: Bool {
        #if os(macOS)
        false
        #else
        UIAccessibility.isBoldTextEnabled
        #endif
    }

    @AppStorage("topEdge", store: .appGroup) var topEdge:
    Double = 20

    @State private var note = ""
    @State var category: CategoryModel?
    @State private var date = Date.now
    @State private var showSmartEntry = false
    /// Non-empty draft → Cancel asks before discarding (HIG error tolerance).
    @State private var showDiscardConfirmation = false

    /// True when closing would throw away work. New entries count once any
    /// field is filled; edits count only once a field actually changed, so
    /// opening and closing an existing transaction never nags.
    private var hasDraft: Bool {
        if let toEdit {
            return padVM.price != toEdit.wrappedAmount
                || note != toEdit.wrappedNote
                || category?.id != toEdit.category?.id
                || income != toEdit.income
                || date != toEdit.wrappedDate
        }
        return padVM.price > 0 || !note.isEmpty || category != nil
    }
    @State private var repeatType = 0
    @State private var repeatCoefficient = 1
    @State private var showRecurring = false
    @State var income = false

    var transactionTypeString: String {
        if income {
            return String.appLocalized("Income")
        } else {
            return String.appLocalized("Expense")
        }
    }

    @State var showCategoryPicker = false
    @State var showCategorySheet = false

    @AppStorage("currency", store: .appGroup) var currency: String = Locale.current.currency?.identifier ?? "USD"
    var currencySymbol: String {
        return Locale.appCurrencySymbol(forCurrencyCode: currency)
    }

    @State var showingDatePicker = false
    @State var showingCategoryView = false

    // toasts
    @State var showToast = false
    @State var toastTitle = ""
    @State var toastImage = ""

    // sensory feedback triggers
    @State private var errorHaptic = 0
    @State private var isSubmitting = false
    @State private var successHaptic = 0
    @State private var lightHaptic = 0

    // shaking category error
    @State var categoryButtonTextColor = Color.SubtitleText
    @State var categoryButtonBackgroundColor = Color.clear
    @State var categoryButtonOutlineColor = Color.Outline
    @State var shake: Bool = false

    @AppStorage(
        "firstTransactionViewLaunch", store: .appGroup)
    var firstLaunch: Bool = true

    // edit mode
    let toEdit: TransactionModel?

    // delete mode

    @State var toDelete: TransactionModel?
    @State var deleteMode = false

    @AppStorage("bottomEdge", store: .appGroup)
    var bottomEdge: Double = 15

    @State private var offset: CGFloat = 0

    let repeatOverlays = ["D", "W", "M"]
    let numberArray = [[1, 2, 3], [4, 5, 6], [7, 8, 9]]

    var repeatChar: String {
        repeatOverlays[max(0, repeatType - 1)]
    }

    func formattedAmount(_ amount: Double) -> String {
        "\(currencySymbol)\(Int(round(amount)))"
    }

    func chipColor(_ hex: String) -> Color {
        Color(hex: hex)
    }

    @ViewBuilder
    var repeatIconWithOverlay: some View {
        Image(systemName: "repeat")
            .font(.subheadline.weight(.semibold))
            
            .overlay(alignment: .topTrailing) {
                repeatOverlayText
            }
            .foregroundStyle(Color.IncomeGreen)
            .padding(7)
            .background(Color.IncomeGreen.opacity(0.23), in: Circle())
            .contentShape(Circle())
    }

    var repeatOverlayText: some View {
        Text(repeatChar)
            .font(.system(size: 6, weight: .black))
            .foregroundStyle(Color.IncomeGreen)
            .frame(width: 10, alignment: .leading)
            .offset(x: 5.7, y: 1.5)
    }

    @ViewBuilder
    func suggestedTransactionLabel(_ transaction: TransactionModel) -> some View {
        HStack(spacing: 3) {
            Text(transaction.wrappedNote)
                .foregroundStyle(Color.PrimaryText)
                .lineLimit(1)
                .padding(.vertical, 3.5)
                .padding(.horizontal, 7)

            suggestedAmountChip(transaction)
        }
        .font(.body.weight(.semibold))
        .padding(5)
        .background(
            Color.SecondaryBackground,
            in: RoundedRectangle(cornerRadius: SBRadius.input, style: .continuous))
    }

    @ViewBuilder
    func suggestedAmountChip(_ transaction: TransactionModel) -> some View {
        let color = chipColor(transaction.wrappedColour)
        Text(formattedAmount(transaction.wrappedAmount))
            .lineLimit(1)
            .foregroundStyle(color)
            .padding(.vertical, 3.5)
            .padding(.horizontal, 5)
            .background(
                color.opacity(0.23),
                in: RoundedRectangle(cornerRadius: SBRadius.pill, style: .continuous))
    }

    @ViewBuilder
    var dateDisplayText: some View {
        let dateStr = getDateString(date: date)
        if isDateToday(date: date) {
            Text(String.appLocalized("Today") + " · " + dateStr)
                .lineLimit(1)
        } else {
            Text(dateStr)
                .lineLimit(1)
        }
    }

    @ViewBuilder
    func deleteButtonLabel(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.title3.weight(.semibold))
            .foregroundStyle(.white)
            .frame(height: 45)
            .frame(maxWidth: .infinity)
            .background(
                color, in: RoundedRectangle(cornerRadius: SBRadius.chip, style: .continuous))
    }

    @ViewBuilder
    func cancelButtonLabel(_ text: String) -> some View {
        Text(text)
            .font(.title3.weight(.semibold))
            .foregroundStyle(Color.PrimaryText.opacity(0.9))
            .frame(height: 45)
            .frame(maxWidth: .infinity)
            .background(
                Color.SecondaryBackground,
                in: RoundedRectangle(cornerRadius: SBRadius.chip, style: .continuous))
    }

    @ViewBuilder
    var deleteConfirmationHeader: some View {
        Group {
            Text(String.appLocalized("Delete Expense?"))
                .font(.title3.weight(.medium))
                .foregroundStyle(Color.PrimaryText)

            Text(String.appLocalized("This action cannot be undone."))
                .font(.callout.weight(.medium))
                .foregroundStyle(Color.SubtitleText)
                .padding(.bottom, 15)
        }
    }

    @ViewBuilder
    var deleteButtonIcon: some View {
        Image(systemName: "trash.fill")
            .font(.subheadline.weight(.semibold))
            
            .foregroundStyle(Color.AlertRed)
            .padding(7)
            .background(Color.AlertRed.opacity(0.23), in: Circle())
            .contentShape(Circle())
    }

    @ViewBuilder
    var topBarButtons: some View {
        HStack {
            // HIG: modals with user input get an explicit Cancel, not "×".
            // Accidental dismissal of a draft asks before discarding.
            Button {
                if hasDraft {
                    showDiscardConfirmation = true
                } else {
                    dismiss()
                }
            } label: {
                Text(String.appLocalized("Cancel"))
                    .font(.body.weight(.medium))
                    .foregroundStyle(Color.PrimaryText)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 4)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel(Text(String.appLocalized("Cancel")))

            Spacer()

            if toEdit != nil {
                Button {
                    toDelete = toEdit
                    deleteMode = true

                } label: {
                    deleteButtonIcon
                }
                .accessibilityLabel(String.appLocalized("delete transaction"))
            }

            Button {
                showRecurring = true
            } label: {
                if repeatType > 0 {
                    repeatIconWithOverlay
                } else {
                    Image(systemName: "repeat")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.SubtitleText)
                        .padding(7)
                        .background(Color.SecondaryBackground, in: Circle())
                        .contentShape(Circle())
                }
            }
            .accessibilityRemoveTraits(.isButton)
            .accessibilityLabel(repeatButtonAccessibility)
            .popover(isPresented: $showRecurring) {
                RecurringPickerView(
                    repeatType: $repeatType, repeatCoefficient: $repeatCoefficient,
                    showMenu: $showRecurring, showPicker: $showPicker)
            }
        }
        .frame(maxWidth: .infinity)
    }

    var incomeExpenseSwipeGesture: some Gesture {
        DragGesture()
            .updating($isDragging) { _, state, _ in
                state = true
            }
            .onChanged { gesture in
                let swipe: CGFloat = gesture.translation.width

                if income {
                    if swipe < 0 {
                        swipingOffset = max(-capsuleWidth, -pow(abs(swipe), 0.8)) + capsuleWidth
                    }
                } else {
                    if swipe > 0 {
                        swipingOffset = min(capsuleWidth, pow(swipe, 0.8))
                    }
                }
            }
            .onEnded { _ in
                handleSwipeEnded()
            }
    }

    func handleSwipeEnded() {
        if income {
            if swipingOffset < (capsuleWidth / 2) {
                withAnimation {
                    swipingOffset = 0
                    income = false
                }
            } else {
                withAnimation {
                    swipingOffset = capsuleWidth
                }
            }
        } else {
            if swipingOffset > (capsuleWidth / 2) {
                withAnimation {
                    swipingOffset = capsuleWidth
                    income = true
                }
            } else {
                withAnimation {
                    swipingOffset = 0
                }
            }
        }
    }

    @ViewBuilder
    var toastOrIncomeExpensePicker: some View {
        VStack {
            if showToast {
                HStack(spacing: 6.5) {
                    Image(systemName: toastImage)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.AlertRed)

                    Text(toastTitle)
                        .font(.body.weight(.semibold))
                        .lineLimit(1)
                        .foregroundStyle(Color.AlertRed)
                }
                .padding(8)
                .background(
                    Color.AlertRed.opacity(0.23),
                    in: RoundedRectangle(cornerRadius: SBRadius.chip, style: .continuous)
                )
                .transition(AnyTransition.opacity.combined(with: .move(edge: .top)))
                .frame(maxWidth: dynamicTypeSize > .xLarge ? 250 : 200)
            } else {
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.SecondaryBackground)
                        .frame(width: capsuleWidth)
                        .offset(x: swipingOffset)

                    HStack(spacing: 0) {
                        expenseToggleButton

                        incomeToggleButton
                    }
                }
                .padding(3)
                .fixedSize(horizontal: true, vertical: true)
                .overlay(Capsule().stroke(Color.Outline.opacity(0.4), lineWidth: 1.3))
            }
        }
    }

    private var smartEntryButton: some View {
        Button {
            showSmartEntry = true
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "sparkles")
                Text(String.appLocalized("智能"))
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(Color.SubtitleText)
            .padding(.horizontal, 9)
            .padding(.vertical, 7)
            .overlay(
                RoundedRectangle(cornerRadius: SBRadius.input, style: .continuous)
                    .stroke(Color.Outline, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(String.appLocalized("智能记账")))
    }

    @ViewBuilder
    var swipeAndNumberPadArea: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                NumberPadTextView(vm: padVM, currencySymbol: currencySymbol)
                // The note pill is sized to its text and capped at
                // screenWidth/1.5, so it still fits next to the smart entry
                // button at accessibility sizes — no need to stack them.
                HStack(spacing: 8) {
                    NoteView(note: $note, focused: $textFieldFocused)
                    smartEntryButton
                }
            }
            // Bottom spacer absorbs every remaining point in the parent VStack
            // so the date row + number pad get pinned to the screen edge.
            // Without this the VStack's intrinsic-size pass gives the pad an
            // extra ~70pt of breathing room below it.
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .simultaneousGesture(incomeExpenseSwipeGesture)
    }

    @ViewBuilder
    var suggestionsOrDateCategoryRow: some View {
        if showingNotePicker {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(suggestedTransactions, id: \.self) { transaction in
                        Button {
                            note = transaction.wrappedNote
                            withAnimation {
                                if padVM.price == 0 {
                                    padVM.price = transaction.wrappedAmount
                                }
                                if category == nil {
                                    category = transaction.category
                                }
                            }
                            self.hideKeyboard()
                        } label: {
                            suggestedTransactionLabel(transaction)
                        }
                    }
                }
            }
            .padding(.bottom, 5)
        } else {
            if usesLargeTextLayout {
                // Large text: two chips side by side would truncate the date.
                VStack(alignment: .leading, spacing: 8) {
                    dateButton
                    categoryButtonArea
                }
                .padding(.bottom, 5)
            } else {
                HStack(spacing: 8) {
                    dateButton

                    categoryButtonArea
                }
                .padding(.bottom, 5)
            }
        }
    }

    @ViewBuilder
    var categoryPickerOrNumberPad: some View {
        if showCategoryPicker {
            TransactionCategoryGrid(
                category: $category,
                showPicker: $showCategoryPicker,
                showingCategoryView: $showCategorySheet,
                income: income
            )
            .environment(categoryVM)
            .transition(AnyTransition.move(edge: .trailing).combined(with: .opacity))
        } else {
            NumberPad(
                vm: padVM,
                showingNotePicker: showingNotePicker,
                category: category
            ) {
                submit()
            }
            .transition(AnyTransition.move(edge: .leading).combined(with: .opacity))
        }
    }

    @ViewBuilder
    var datePickerOverlay: some View {
        ZStack(alignment: .bottom) {
            GeometryReader { _ in
                EmptyView()
            }
            .background(Color.black)
            .opacity(showingDatePicker ? 0.3 : 0)
            .onTapGesture {
                showingDatePicker = false
            }

            DatePicker(String.appLocalized("Date"), selection: $date)
                .datePickerStyle(.graphical)
                .padding(.horizontal, 15)
                .padding(.vertical, 8)
                .systemCard(in: RoundedRectangle(cornerRadius: SBRadius.card))
                .padding(17)
                .onChange(of: dateString) { _, _ in
                    handleDateChanged()
                }
                .padding(.bottom, 10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .opacity(showingDatePicker ? 1 : 0)
        .allowsHitTesting(showingDatePicker)
        .animation(.easeOut(duration: 0.25), value: showingDatePicker)
    }

    func handleDateChanged() {
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(300))
            showingDatePicker = false
        }

        if date > Date.now {
            animateIcon = true
        } else {
            animateIcon = false
        }
    }

    @ViewBuilder
    var dateButton: some View {
        // Two candidate layouts: date + time, or date alone when the row is
        // too narrow. `ViewThatFits` measures the real container, which is
        // what the old screen-width arithmetic was approximating.
        ViewThatFits(in: .horizontal) {
            dateRow(withTime: true)
            dateRow(withTime: false)
        }
        .foregroundStyle(Color.PrimaryText)
        .padding(.vertical, 8.5)
        .padding(.horizontal, 10)
        .animation(.default, value: isDateToday(date: date))
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(
            RoundedRectangle(cornerRadius: SBRadius.input, style: .continuous)
                .strokeBorder(Color.Outline, lineWidth: 1.5)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            hideKeyboard()
            showingDatePicker = true
        }
    }

    @ViewBuilder
    private func dateRow(withTime: Bool) -> some View {
        HStack(spacing: 7) {
            Group {
                if date < Date.now {
                    Image(systemName: "calendar")
                } else {
                        Image(systemName: "rays")
                            .symbolEffect(
                                .variableColor.iterative.dimInactiveLayers.nonReversing,
                                options: .repeating, value: animateIcon)
                }
            }
            .foregroundStyle(Color.SubtitleText)
            .font(.subheadline.weight(.semibold))

            Group {
                dateDisplayText
            }
            .font(.body.weight(.semibold))

            if withTime {
                Spacer(minLength: 8)

                Text(getTimeString(date: date))
                    .font(.body.weight(.semibold))
            }
        }
    }

    @ViewBuilder
    var categoryButtonArea: some View {
        if (categoryVM.expenseCategories.count == 0 && !income) || (categoryVM.incomeCategories.count == 0 && income) {
            emptyCategoryButton
        } else {
            Group {
                if showCategoryPicker {
                    HStack(spacing: 10) {
                        Text(String.appLocalized("Close"))
                            .font(.body.weight(.semibold))
                            .lineLimit(1)
                    }
                    .padding(.vertical, 8.5)
                    .padding(.horizontal, 10)
                    .frame(width: widthOfCategoryButton)
                    .foregroundStyle(Color.AlertRed)
                    .background(Color.AlertRed.opacity(0.23),
                        in: RoundedRectangle(cornerRadius: SBRadius.input, style: .continuous)
                    )
                } else {
                    if let unwrappedCategory = category {
                        categoryChip(unwrappedCategory)
                    } else {
                        noCategoryButton
                            .offset(x: shake ? -5 : 0)
                    }
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.easeInOut) {
                    showCategoryPicker.toggle()
                }
            }
        }
    }

    @ViewBuilder
    func categoryChip(_ category: CategoryModel) -> some View {
        let color = chipColor(category.wrappedColour)
        HStack(spacing: 5) {
            Text(category.wrappedEmoji)
                .font(.footnote.weight(.semibold))

            Text(category.wrappedName)
                .font(.body.weight(.semibold))
                .lineLimit(1)
        }
        .padding(.vertical, 8.5)
        .padding(.horizontal, 10)
        .foregroundStyle(color)
        .background(
            color.opacity(0.35),
            in: RoundedRectangle(cornerRadius: SBRadius.input, style: .continuous)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            showCategoryPicker = true
        }
    }

    @ViewBuilder
    var emptyCategoryButton: some View {
        HStack(spacing: 4) {
            Image(systemName: "plus")
                .font(.subheadline.weight(.semibold))

            Text(String.appLocalized("Category"))
                .font(.body.weight(.semibold))
                .lineLimit(1)
        }
        .padding(.vertical, 8.5)
        .padding(.horizontal, 10)
        .foregroundStyle(categoryButtonTextColor)
        .background(
            categoryButtonBackgroundColor,
            in: RoundedRectangle(cornerRadius: SBRadius.input, style: .continuous)
        )
        .contentShape(Rectangle())
        .overlay(
            RoundedRectangle(cornerRadius: SBRadius.input, style: .continuous)
                .strokeBorder(categoryButtonOutlineColor, lineWidth: 1.5)
        )
        .drawingGroup()
        .offset(x: shake ? -5 : 0)
        .contentShape(Rectangle())
        .onTapGesture {
            // Always use the grid picker, even before any category exists;
            // its empty state offers starter categories.
            withAnimation(.easeInOut) {
                showCategoryPicker = true
            }
        }
    }

    @ViewBuilder
    var noCategoryButton: some View {
        HStack(spacing: 5.5) {
                Image(systemName: "circle.grid.2x2")
                    .font(.subheadline.weight(.semibold))
                    .symbolEffect(
                        .bounce.up.byLayer, options: .repeating.speed(0.5),
                        value: showCategoryPicker)

            Text(String.appLocalized("Category"))
                .font(.body.weight(.semibold))
                .lineLimit(1)
        }
        .padding(.vertical, 8.5)
        .padding(.horizontal, 10)
        .frame(width: widthOfCategoryButton)
        .foregroundStyle(categoryButtonTextColor)
        .background(
            categoryButtonBackgroundColor,
            in: RoundedRectangle(cornerRadius: SBRadius.input, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: SBRadius.input, style: .continuous)
                .strokeBorder(categoryButtonOutlineColor, lineWidth: 1.5)
        )
        .drawingGroup()
    }

    @ViewBuilder
    var expenseToggleButton: some View {
        Text(String.appLocalized("Expense"))
            .font(.body.weight(.semibold))
            .lineLimit(1)
            .foregroundStyle(income == false ? Color.PrimaryText : Color.SubtitleText)
            .padding(6)
            .frame(width: capsuleWidth)
            .contentShape(Rectangle())
            .onTapGesture {
                DispatchQueue.main.async {
                    withAnimation(.easeIn(duration: 0.15)) {
                        income = false
                        swipingOffset = 0
                    }
                }
            }
    }

    @ViewBuilder
    var incomeToggleButton: some View {
        Text(String.appLocalized("transaction-view-income-picker"))
            .font(.body.weight(.semibold))
            .lineLimit(1)
            .foregroundStyle(income == true ? Color.PrimaryText : Color.SubtitleText)
            .padding(6)
            .frame(width: capsuleWidth)
            .contentShape(Rectangle())
            .onTapGesture {
                DispatchQueue.main.async {
                    withAnimation(.easeIn(duration: 0.15)) {
                        income = true
                        swipingOffset = capsuleWidth
                    }
                }
            }
    }

    var dateString: String {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale.appLocale
        dateFormatter.dateFormat = "d MMM yyyy"
        return dateFormatter.string(from: date)
    }

    var repeatButtonAccessibility: String {
        if repeatType == 1 {
            return String.appLocalized("transaction recurs daily, button to edit recurring duration")
        } else if repeatType == 2 {
            return String.appLocalized("transaction recurs weekly, button to edit recurring duration")
        } else if repeatType == 3 {
            return String.appLocalized("transaction recurs monthly, button to edit recurring duration")
        } else {
            return String.appLocalized("button to make transaction recurring")
        }
    }

    @ViewBuilder
    var deleteConfirmationOverlay: some View {
        ZStack(alignment: .bottom) {
            Color.clear
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .onTapGesture {
                    deleteMode = false
                    toDelete = nil
                }

            VStack(alignment: .leading, spacing: 1.5) {
                deleteConfirmationHeader

                Button {
                    deleteMode = false

                    withAnimation {
                        if let itemToDelete = toDelete {
                            transactionVM.delete(itemToDelete)
                        }
                    }

                    dismiss()

                } label: {
                    deleteButtonLabel(String.appLocalized("Delete"), color: Color.AlertRed)
                }
                .padding(.bottom, 8)

                Button {
                    withAnimation(.easeOut(duration: 0.7)) {
                        deleteMode = false
                        toDelete = nil
                    }

                } label: {
                    cancelButtonLabel(String.appLocalized("Cancel"))
                }
            }
            .padding(13)
            .systemCard(in: RoundedRectangle(cornerRadius: SBRadius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: SBRadius.card).stroke(
                    systemColorScheme == .dark ? Color.gray.opacity(0.1) : Color.clear, lineWidth: 1.3)
            )
            .offset(y: offset)
            .gesture(
                DragGesture()
                    .onChanged { gesture in
                        if gesture.translation.height < 0 {
                            offset = gesture.translation.height / 3
                        } else {
                            offset = gesture.translation.height
                        }
                    }
                    .onEnded { value in
                        if value.translation.height > 20 {
                            deleteMode = false
                            toDelete = nil
                        } else {
                            withAnimation {
                                offset = 0
                            }
                        }
                    }
            )
            .padding(.horizontal, 17)
            .padding(.bottom, bottomEdge == 0 ? 12 : bottomEdge - 3)
        }
        .ignoresSafeArea(.all)
        .background(BackgroundBlurView())
    }

    @AppStorage("colourScheme", store: .appGroup)
    var colourScheme: Int = 0

    @Environment(\.colorScheme) var systemColorScheme

    var darkMode: Bool {
        (colourScheme == 0 && systemColorScheme == .dark) || colourScheme == 2
    }

    var backgroundColor: Color {
        if darkMode {
            return Color("AlwaysDarkBackground")
        } else {
            return Color("AlwaysLightBackground")
        }
    }

    @State var showPicker = false
    @State var animateIcon = false

    @Namespace var animation

    @State var swipingOffset: CGFloat = 0
    @GestureState var isDragging = false

    // show recommendations

    @State var textFieldFocused: Bool = false

    @AppStorage(
        "showTransactionRecommendations", store: .appGroup)
    var showRecommendations: Bool = false

    var suggestedTransactions: [TransactionModel] {
        return transactionVM.suggestedNotes(query: note, category: category, income: income)
    }

    var showingNotePicker: Bool {
        return note != "" && toEdit == nil && !suggestedTransactions.isEmpty && textFieldFocused
        && showRecommendations
    }

    @Environment(\.dynamicTypeSize) var dynamicTypeSize

    var fontSize: CGFloat {
        switch dynamicTypeSize {
        case .xSmall:
            return 14
        case .small:
            return 15
        case .medium:
            return 16
        case .large:
            return 17
        case .xLarge:
            return 19
        case .xxLarge:
            return 21
        case .xxxLarge:
            return 23
        default:
            return 23
        }
    }

    var widthOfCategoryButton: CGFloat {
        let fontSize = UIFont.getBodyFontSize(dynamicTypeSize: dynamicTypeSize)

        return "Category".widthOfRoundedString(size: fontSize, weight: .semibold) + 50
    }

    /// Two chips and the header no longer fit on a 375pt phone from xxLarge
    /// up, so switch to the stacked layout there (not just at AX sizes).
    var usesLargeTextLayout: Bool {
        dynamicTypeSize >= .xxLarge
    }

    var capsuleWidth: CGFloat {
        // Stacked header at large sizes, so each half can be wide enough for
        // the localized "Expense"/"Income" labels.
        usesLargeTextLayout ? 140 : 100
    }

    @State private var padVM = NumberPadViewModel(numberEntryType: 1, hapticType: 1)
    @AppStorage("numberEntryType", store: .appGroup)
    var numberEntryType: Int = 1

    /// `currency` is declared at the top of the struct (line ~45) and re-read
    /// here. We just need the `currencySymbol` derived from the existing
    /// `currency` value to pass into `NumberPadTextView`.

    @ViewBuilder
    var headerArea: some View {
        if usesLargeTextLayout {
            // At large sizes the Cancel/repeat buttons overlap the
            // income/expense capsule on narrow phones, so give each its row.
            VStack(spacing: 8) {
                topBarButtons
                toastOrIncomeExpensePicker
            }
            .padding(.top, topEdge)
        } else {
            toastOrIncomeExpensePicker
                .frame(maxWidth: .infinity)
                .overlay {
                    topBarButtons
                }
                .padding(.top, topEdge)
        }
    }

    var body: some View {
        GeometryReader { proxy in
            VStack(spacing: 8) {
                // income/expense picker
                headerArea

                swipeAndNumberPadArea

                suggestionsOrDateCategoryRow

                // date and category picker
                categoryPickerOrNumberPad

            }
            .padding(17)
            // Cap the entry layout on iPad/Mac so the keypad doesn't stretch
            // edge to edge; centred by the outer frame.
            .frame(width: min(proxy.size.width, 560), height: proxy.size.height)
            .frame(maxWidth: .infinity)
            .background(Color.clear)
            .onTapGesture {
                self.hideKeyboard()
            }
            .fullScreenPresentation(isPresented: $deleteMode) {
                deleteConfirmationOverlay
            }
            .overlay {
                datePickerOverlay
            }
        }
        
        .animation(.easeOut(duration: 0.2), value: showToast)
        .appBackground()
        #if os(macOS)
        // A sheet has no intrinsic size; the entry screen is a fixed
        // calculator-like surface, so give it one.
        .frame(minWidth: 520, idealWidth: 560, minHeight: 720)
        #else
        .ignoresSafeArea(.keyboard, edges: .all)
        .frame(maxHeight: .infinity)
        .ignoresSafeArea(.all)
        #endif
        // Control-dense surface (keypad + fixed rows). Let text grow to the
        // first accessibility size, then stop: beyond that the keypad and the
        // date/category row cannot fit on a phone. Documented exception to
        // unlimited scaling, same approach as Apple's Calculator.
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        .onChange(of: showToast) { _, newValue in
            if newValue {
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(2))
                    showToast = false
                }
            }
        }
        .onChange(of: income) { _, newValue in
            lightHaptic &+= 1
            // Only drop a category that belongs to the other side; clearing
            // unconditionally wiped the category when editing an income
            // transaction (onAppear sets `income` after `category`).
            if let category, category.income != newValue {
                self.category = nil
            }
        }
        .onChange(of: numberEntryType) { _, new in
            padVM.numberEntryType = new
        }
        .onChange(of: isDragging) { _, _ in
            if !isDragging {
                if income {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        swipingOffset = capsuleWidth
                    }
                } else {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        swipingOffset = 0
                    }
                }
            }
        }
        .onAppear {
            categoryVM.load()
            // The init can't read `capsuleWidth`, so re-align the income
            // capsule once the environment (and its type size) is known.
            if income {
                swipingOffset = capsuleWidth
            }
            // Sync the pad's numberEntryType with the AppStorage flag at the
            // moment the view first appears. Subsequent changes are picked up
            // by the `.onChange(of: numberEntryType)` modifier above.
            padVM.numberEntryType = numberEntryType
            DispatchQueue.main.async {
                if let transaction = toEdit {
                    repeatType = Int(transaction.recurringType)
                    repeatCoefficient = Int(transaction.recurringCoefficient)
                    padVM.price = transaction.wrappedAmount

                    if transaction.wrappedAmount.truncatingRemainder(dividingBy: 1) > 0 && numberEntryType == 2 {
                        padVM.isEditingDecimal = true
                    }

                    if transaction.wrappedDate > Date.now {
                        animateIcon = true
                    }
                }
            }
        }
        .sheet(isPresented: $showCategorySheet) {
            CategoryView(mode: .transaction, income: income) { selected in
                category = selected
                // Picking a category also clears a pending "missing
                // category" highlight left over from a failed submit.
                categoryButtonTextColor = Color.SubtitleText
                categoryButtonBackgroundColor = Color.clear
                categoryButtonOutlineColor = Color.Outline
            }
        }
        .sheet(isPresented: $showSmartEntry) {
            SmartEntrySheet(
                expenseCategories: categoryVM.expenseCategories,
                incomeCategories: categoryVM.incomeCategories
            ) { parsed in
                applyParsed(parsed)
            }
        }
        .alert(String.appLocalized("Discard this entry?"), isPresented: $showDiscardConfirmation) {
            Button(String.appLocalized("Keep Editing"), role: .cancel) {}
            Button(String.appLocalized("Discard"), role: .destructive) { dismiss() }
        }
        .sheet(isPresented: $showPicker) {
                CustomRecurringView(
                    repeatType: $repeatType, repeatCoefficient: $repeatCoefficient, showPicker: $showPicker
                )
                .presentationDetents([.medium, .large])
        }
        .onChange(of: dynamicTypeSize) { _, _ in
            if income {
                swipingOffset = capsuleWidth
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: lightHaptic)
        .sensoryFeedback(.error, trigger: errorHaptic)
        .sensoryFeedback(.success, trigger: successHaptic)
    }

    func isDateToday(date: Date) -> Bool {
        let calendar = Calendar.current

        return calendar.isDateInToday(date)
    }

    func getDateString(date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.appLocale
        // Localized template: zh gives "10月19日", en gives "Oct 19".
        // A fixed "d MMM" pattern rendered as "19 10月" in Chinese.
        formatter.setLocalizedDateFormatFromTemplate(isDateToday(date: date) ? "MMMd" : "MMMdEEE")
        return formatter.string(from: date)
    }

    func getTimeString(date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.appLocale

        formatter.dateFormat = "HH:mm"

        return formatter.string(from: date)
    }

    func toggleFieldColors() {
        if categoryButtonTextColor == Color.AlertRed
            || categoryButtonBackgroundColor == Color.AlertRed.opacity(0.23) {
            withAnimation(.linear) {
                categoryButtonTextColor = Color.SubtitleText
                categoryButtonBackgroundColor = Color.clear
                categoryButtonOutlineColor = Color.Outline
            }
        } else {
            withAnimation(.easeOut(duration: 1.0)) {
                categoryButtonTextColor = Color.AlertRed
                categoryButtonBackgroundColor = Color.AlertRed.opacity(0.23)
                categoryButtonOutlineColor = Color.AlertRed
            }
            withAnimation(.easeInOut(duration: 0.1).repeatCount(5)) {
                shake = true
            }
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(500))
                withAnimation(.easeInOut(duration: 0.1)) {
                    shake = false
                }
                withAnimation(.easeOut(duration: 0.6)) {
                    categoryButtonTextColor = Color.SubtitleText
                    categoryButtonBackgroundColor = Color.clear
                    categoryButtonOutlineColor = Color.Outline
                }
            }
        }

    }

    /// Fills the form from a smart-entry parse result. Nothing is saved here —
    /// the user still submits the form themselves.
    private func applyParsed(_ parsed: ParsedExpense) {
        income = parsed.isIncome
        padVM.price = Money.double(parsed.amount)
        if note.isEmpty, let merchant = parsed.merchant {
            note = merchant
        }
        let pool = parsed.isIncome ? categoryVM.incomeCategories : categoryVM.expenseCategories
        if let match = ExpenseTextParser.resolveCategory(parsed.categoryHint, from: pool) {
            category = match
        }
    }

    func submit() {
        // A fast double tap on the checkmark used to create two rows.
        guard !isSubmitting else { return }
        isSubmitting = true

        let amount = padVM.price

        if amount == 0 && category == nil {
            toastImage = "questionmark.app"
            toastTitle = String.appLocalized("Incomplete Entry")
            showToast = true
            toggleFieldColors()

            errorHaptic &+= 1
            isSubmitting = false

            return
        } else if amount == 0 {
            toastImage = "centsign.circle"
            toastTitle = String.appLocalized("Missing Amount")
            showToast = true
            errorHaptic &+= 1
            isSubmitting = false
            return
        } else if category == nil {
            toastImage = "tray"
            toastTitle = String.appLocalized("Missing Category")
            showToast = true

            toggleFieldColors()

            errorHaptic &+= 1
            isSubmitting = false
            return
        }

        successHaptic &+= 1

        if let editedTransaction = toEdit {
            let trimmedNote = note.trimmingCharacters(in: .whitespaces)
            let finalNote: String
            if let category {
                finalNote = trimmedNote.isEmpty ? category.wrappedName : trimmedNote
            } else {
                finalNote = trimmedNote
            }

            transactionVM.update(
                editedTransaction,
                note: finalNote,
                category: category,
                income: income,
                amount: amount,
                date: date,
                repeatType: repeatType,
                repeatCoefficient: repeatCoefficient
            )

            dismiss()

            return
        }

        transactionVM.create(
            note: note.trimmingCharacters(in: .whitespacesAndNewlines) == ""
                ? (category?.wrappedName ?? "") : note.trimmingCharacters(in: .whitespaces),
            category: category,
            income: income,
            amount: amount,
            date: date,
            repeatType: repeatType,
            repeatCoefficient: repeatCoefficient
        )

        // Reset pad state (price / decimal / haptic trigger) for the next
        // entry. The pad's submit button also clears the VM via `vm.submit()`,
        // but we clear again here in case the user taps a different commit
        // path (e.g. via the keyboard return key) before the pad re-renders.
        padVM.submit()
        dismiss()
    }

    init(toEdit: TransactionModel? = nil) {
        if let transaction = toEdit {
            _note = State(initialValue: transaction.wrappedNote)

            if let unwrappedCategory = transaction.category {
                _category = State(initialValue: unwrappedCategory)
            }

            _income = State(initialValue: transaction.income)

            if transaction.income {
                _swipingOffset = State(initialValue: 100)
            }

            _date = State(initialValue: transaction.date ?? Date.now)
        }
        self.toEdit = toEdit
    }

    init(category: CategoryModel? = nil) {
        if let unwrappedCategory = category {
            _income = State(initialValue: false)
            _category = State(initialValue: unwrappedCategory)
        }

        toEdit = nil
    }
}

