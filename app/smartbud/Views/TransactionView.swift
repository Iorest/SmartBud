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
        UIAccessibility.isBoldTextEnabled
    }

    @AppStorage("topEdge", store: .appGroup) var topEdge:
    Double = 20

    @State private var note = ""
    @State var category: CategoryModel?
    @State private var date = Date.now
    @State private var showSmartEntry = false
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
            .font(.system(.subheadline, design: .rounded).weight(.semibold))
            .dynamicTypeSize(...DynamicTypeSize.xxLarge)
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
            .font(.system(size: 6, weight: .black, design: .rounded))
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
        .font(.system(.body, design: .rounded).weight(.semibold))
        .padding(5)
        .background(
            Color.SecondaryBackground,
            in: RoundedRectangle(cornerRadius: GlassRadius.input, style: .continuous))
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
                in: RoundedRectangle(cornerRadius: GlassRadius.pill, style: .continuous))
    }

    @ViewBuilder
    var dateDisplayText: some View {
        let dateStr = getDateString(date: date)
        if isDateToday(date: date) {
            Text(String(localized: "Today, \(dateStr)"))
                .lineLimit(1)
        } else {
            Text(dateStr)
                .lineLimit(1)
        }
    }

    @ViewBuilder
    func deleteButtonLabel(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 20, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)
            .frame(height: 45)
            .frame(maxWidth: .infinity)
            .background(
                color, in: RoundedRectangle(cornerRadius: GlassRadius.chip, style: .continuous))
    }

    @ViewBuilder
    func cancelButtonLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 20, weight: .semibold, design: .rounded))
            .foregroundStyle(Color.PrimaryText.opacity(0.9))
            .frame(height: 45)
            .frame(maxWidth: .infinity)
            .background(
                Color.SecondaryBackground,
                in: RoundedRectangle(cornerRadius: GlassRadius.chip, style: .continuous))
    }

    @ViewBuilder
    var deleteConfirmationHeader: some View {
        Group {
            Text(String.appLocalized("Delete Expense?"))
                .font(.system(size: 20, weight: .medium, design: .rounded))
                .foregroundStyle(Color.PrimaryText)

            Text(String.appLocalized("This action cannot be undone."))
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundStyle(Color.SubtitleText)
                .padding(.bottom, 15)
        }
    }

    @ViewBuilder
    var closeButtonIcon: some View {
        Image(systemName: "xmark")
            .font(.system(.subheadline, design: .rounded).weight(.semibold))
            .dynamicTypeSize(...DynamicTypeSize.xxLarge)
            .foregroundStyle(Color.SubtitleText)
            .padding(7)
            .background(Color.SecondaryBackground, in: Circle())
            .contentShape(Circle())
    }

    @ViewBuilder
    var deleteButtonIcon: some View {
        Image(systemName: "trash.fill")
            .font(.system(.subheadline, design: .rounded).weight(.semibold))
            .dynamicTypeSize(...DynamicTypeSize.xxLarge)
            .foregroundStyle(Color.AlertRed)
            .padding(7)
            .background(Color.AlertRed.opacity(0.23), in: Circle())
            .contentShape(Circle())
    }

    @ViewBuilder
    var topBarButtons: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                closeButtonIcon
            }

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
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(Color.AlertRed)

                    Text(toastTitle)
                        .font(.system(.body, design: .rounded).weight(.semibold))
                        .lineLimit(1)
                        .foregroundStyle(Color.AlertRed)
                }
                .padding(8)
                .background(
                    Color.AlertRed.opacity(0.23),
                    in: RoundedRectangle(cornerRadius: GlassRadius.chip, style: .continuous)
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

    @ViewBuilder
    var swipeAndNumberPadArea: some View {        VStack(spacing: 0) {
            VStack(spacing: 8) {
                NumberPadTextView(vm: padVM, currencySymbol: currencySymbol)
                HStack(spacing: 8) {
                    NoteView(note: $note, focused: $textFieldFocused)
                    Button {
                        showSmartEntry = true
                    } label: {
                        Image(systemName: "sparkles")
                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                            .foregroundStyle(Color.SubtitleText)
                            .padding(7)
                            .overlay(
                                RoundedRectangle(cornerRadius: GlassRadius.input, style: .continuous)
                                    .stroke(Color.Outline, lineWidth: 1.5)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(String.appLocalized("智能记账")))
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
            HStack(spacing: 8) {
                dateButton

                categoryButtonArea
            }
            .padding(.bottom, 5)
        }
    }

    @ViewBuilder
    var categoryPickerOrNumberPad: some View {
        if showCategoryPicker {
            NewCategoryPickerView(
                category: $category, showPicker: $showCategoryPicker,
                showSheet: $showCategorySheet, income: income
            )
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
                .glassCard(in: RoundedRectangle(cornerRadius: GlassRadius.card))
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
            .font(.system(.subheadline, design: .rounded).weight(.semibold))

            Group {
                dateDisplayText
            }
            .font(.system(.body, design: .rounded).weight(.semibold))

            if showTime {
                Spacer()

                Text(getTimeString(date: date))
                    .font(.system(.body, design: .rounded).weight(.semibold))
            }
        }
        .foregroundStyle(Color.PrimaryText)
        .padding(.vertical, 8.5)
        .padding(.horizontal, 10)
        .animation(.default, value: isDateToday(date: date))
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(
            RoundedRectangle(cornerRadius: GlassRadius.input, style: .continuous)
                .strokeBorder(Color.Outline, lineWidth: 1.5)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            UIApplication.shared.endEditing()
            showingDatePicker = true
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
                            .font(.system(.body, design: .rounded).weight(.semibold))
                            .lineLimit(1)
                    }
                    .padding(.vertical, 8.5)
                    .padding(.horizontal, 10)
                    .frame(width: widthOfCategoryButton)
                    .foregroundStyle(Color.AlertRed)
                    .background(Color.AlertRed.opacity(0.23),
                        in: RoundedRectangle(cornerRadius: GlassRadius.input, style: .continuous)
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
                .font(.system(.footnote, design: .rounded).weight(.semibold))

            Text(category.wrappedName)
                .font(.system(.body, design: .rounded).weight(.semibold))
                .lineLimit(1)
        }
        .padding(.vertical, 8.5)
        .padding(.horizontal, 10)
        .foregroundStyle(color)
        .background(
            color.opacity(0.35),
            in: RoundedRectangle(cornerRadius: GlassRadius.input, style: .continuous)
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
                .font(.system(.subheadline, design: .rounded).weight(.semibold))

            Text(String.appLocalized("Category"))
                .font(.system(.body, design: .rounded).weight(.semibold))
                .lineLimit(1)
        }
        .padding(.vertical, 8.5)
        .padding(.horizontal, 10)
        .foregroundStyle(categoryButtonTextColor)
        .background(
            categoryButtonBackgroundColor,
            in: RoundedRectangle(cornerRadius: GlassRadius.input, style: .continuous)
        )
        .contentShape(Rectangle())
        .overlay(
            RoundedRectangle(cornerRadius: GlassRadius.input, style: .continuous)
                .strokeBorder(categoryButtonOutlineColor, lineWidth: 1.5)
        )
        .drawingGroup()
        .offset(x: shake ? -5 : 0)
        .contentShape(Rectangle())
        .onTapGesture {
            showCategorySheet = true
        }
    }

    @ViewBuilder
    var noCategoryButton: some View {
        HStack(spacing: 5.5) {
                Image(systemName: "circle.grid.2x2")
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .symbolEffect(
                        .bounce.up.byLayer, options: .repeating.speed(0.5),
                        value: showCategoryPicker)

            Text(String.appLocalized("Category"))
                .font(.system(.body, design: .rounded).weight(.semibold))
                .lineLimit(1)
        }
        .padding(.vertical, 8.5)
        .padding(.horizontal, 10)
        .frame(width: widthOfCategoryButton)
        .foregroundStyle(categoryButtonTextColor)
        .background(
            categoryButtonBackgroundColor,
            in: RoundedRectangle(cornerRadius: GlassRadius.input, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: GlassRadius.input, style: .continuous)
                .strokeBorder(categoryButtonOutlineColor, lineWidth: 1.5)
        )
        .drawingGroup()
    }

    @ViewBuilder
    var expenseToggleButton: some View {
        Text(String.appLocalized("Expense"))
            .font(.system(.body, design: .rounded).weight(.semibold))
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
            .font(.system(.body, design: .rounded).weight(.semibold))
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
            .glassCard(in: RoundedRectangle(cornerRadius: GlassRadius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: GlassRadius.card).stroke(
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

    var showTime: Bool {
        let roundedFont = UIFont.rounded(ofSize: fontSize, weight: .semibold)

        let attributes = [NSAttributedString.Key.font: roundedFont]

        let dateSize: CGSize

        if isDateToday(date: date) {
            dateSize = (("Today, " + getDateString(date: date)) as NSString).size(
                withAttributes: attributes)
        } else {
            dateSize = (getDateString(date: date) as NSString).size(withAttributes: attributes)
        }

        let categorySize = (category?.fullName ?? "X Category").size(withAttributes: attributes)
        let timeSize = (getTimeString(date: date) as NSString).size(withAttributes: attributes)

        let screenWidth: CGFloat

        if boldText {
            screenWidth = (ScreenSize.width - 200)
        } else {
            screenWidth = (ScreenSize.width - 150)
        }

        if (dateSize.width + categorySize.width + timeSize.width) > screenWidth {
            return false
        } else {
            return true
        }
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

    var capsuleWidth: CGFloat {
        if dynamicTypeSize > .xLarge {
            return 120
        } else {
            return 100
        }
    }

    @State private var padVM = NumberPadViewModel(numberEntryType: 1, hapticType: 1)
    @AppStorage("numberEntryType", store: .appGroup)
    var numberEntryType: Int = 1

    /// `currency` is declared at the top of the struct (line ~45) and re-read
    /// here. We just need the `currencySymbol` derived from the existing
    /// `currency` value to pass into `NumberPadTextView`.

    var body: some View {
        GeometryReader { proxy in
            VStack(spacing: 8) {
                // income/expense picker
                toastOrIncomeExpensePicker
                //                .frame(height: 50, alignment: .top)
                .frame(maxWidth: .infinity)
                .overlay {
                    topBarButtons
                }
                .padding(.top, topEdge)

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
            .fullScreenCover(isPresented: $deleteMode) {
                deleteConfirmationOverlay
            }
            .overlay {
                datePickerOverlay
            }
        }
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .animation(.easeOut(duration: 0.2), value: showToast)
        .ignoresSafeArea(.keyboard, edges: .all)
        .frame(maxHeight: .infinity)
        .appBackground()
        .ignoresSafeArea(.all)
        .onChange(of: showToast) { _, newValue in
            if newValue {
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(2))
                    showToast = false
                }
            }
        }
        .onChange(of: income) { _, _ in
            lightHaptic &+= 1
            category = nil
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
            CategoryView(mode: .transaction, income: income)
        }
        .sheet(isPresented: $showSmartEntry) {
            SmartEntrySheet(
                expenseCategories: categoryVM.expenseCategories,
                incomeCategories: categoryVM.incomeCategories
            ) { parsed in
                applyParsed(parsed)
            }
        }
        .sheet(isPresented: $showPicker) {
                CustomRecurringView(
                    repeatType: $repeatType, repeatCoefficient: $repeatCoefficient, showPicker: $showPicker
                )
                .presentationDetents([.height(230)])
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

        if isDateToday(date: date) {
            formatter.dateFormat = "d MMM"

            return formatter.string(from: date)
        } else {
            formatter.dateFormat = "E, d MMM"

            return formatter.string(from: date)
        }
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
        let amount = padVM.price

        if amount == 0 && category == nil {
            toastImage = "questionmark.app"
            toastTitle = String.appLocalized("Incomplete Entry")
            showToast = true
            toggleFieldColors()

            errorHaptic &+= 1

            return
        } else if amount == 0 {
            toastImage = "centsign.circle"
            toastTitle = String.appLocalized("Missing Amount")
            showToast = true
            errorHaptic &+= 1
            return
        } else if category == nil {
            toastImage = "tray"
            toastTitle = String.appLocalized("Missing Category")
            showToast = true

            toggleFieldColors()

            errorHaptic &+= 1
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

