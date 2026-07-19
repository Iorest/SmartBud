//
//  TransactionView.swift
//  xpenz
//
//  Created by Rafael Soh on 14/5/22.
//

import Combine
import Foundation
import SwiftUI

struct TransactionView: View {
    @EnvironmentObject var categoryVM: CategoryViewModel
    @EnvironmentObject var transactionVM: TransactionViewModel

    @Environment(\.dismiss) var dismiss

    @Environment(\.colorScheme) var colorScheme
    var boldText: Bool {
        UIAccessibility.isBoldTextEnabled
    }

    @AppStorage("topEdge", store: UserDefaults(suiteName: "group.com.rafaelsoh.dime")) var topEdge:
    Double = 20

    @State private var note = ""
    @State var category: CategoryModel?
    @State private var date = Date.now
    @State private var repeatType = 0
    @State private var repeatCoefficient = 1
    @State private var showRecurring = false
    @State var income = false

    var transactionTypeString: String {
        if income {
            return String(localized: "Income")
        } else {
            return String(localized: "Expense")
        }
    }

    @State var showCategoryPicker = false
    @State var showCategorySheet = false

    @AppStorage("currency", store: UserDefaults(suiteName: "group.com.rafaelsoh.dime")) var currency: String = Locale.current.currency?.identifier ?? "USD"
    var currencySymbol: String {
        return Locale.current.localizedCurrencySymbol(forCurrencyCode: currency)!
    }

    @State var showingDatePicker = false
    @State var showingCategoryView = false

    // toasts
    @State var showToast = false
    @State var toastTitle = ""
    @State var toastImage = ""

    // shaking category error
    @State var categoryButtonTextColor = Color.SubtitleText
    @State var categoryButtonBackgroundColor = Color.clear
    @State var categoryButtonOutlineColor = Color.Outline
    @State var shake: Bool = false

    @AppStorage(
        "firstTransactionViewLaunch", store: UserDefaults(suiteName: "group.com.rafaelsoh.dime"))
    var firstLaunch: Bool = true

    // edit mode
    let toEdit: TransactionModel?

    // delete mode

    @State var toDelete: TransactionModel?
    @State var deleteMode = false

    @AppStorage("bottomEdge", store: UserDefaults(suiteName: "group.com.rafaelsoh.dime"))
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
            .foregroundColor(Color.IncomeGreen)
            .padding(7)
            .background(Color.IncomeGreen.opacity(0.23), in: Circle())
            .contentShape(Circle())
    }

    var repeatOverlayText: some View {
        Text(repeatChar)
            .font(.system(size: 6, weight: .black, design: .rounded))
            .foregroundColor(Color.IncomeGreen)
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
            in: RoundedRectangle(cornerRadius: 11.5, style: .continuous))
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
                in: RoundedRectangle(cornerRadius: 6.5, style: .continuous))
    }

    @ViewBuilder
    var dateDisplayText: some View {
        let dateStr = getDateString(date: date)
        if isDateToday(date: date) {
            Text(String(format: String(localized: "Today, %@"), dateStr))
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
            .foregroundColor(.white)
            .frame(height: 45)
            .frame(maxWidth: .infinity)
            .background(
                color, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
    }

    @ViewBuilder
    func cancelButtonLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 20, weight: .semibold, design: .rounded))
            .foregroundColor(Color.PrimaryText.opacity(0.9))
            .frame(height: 45)
            .frame(maxWidth: .infinity)
            .background(
                Color.SecondaryBackground,
                in: RoundedRectangle(cornerRadius: 9, style: .continuous))
    }

    @ViewBuilder
    var deleteConfirmationHeader: some View {
        Group {
            Text(String(localized: "Delete Expense?"))
                .font(.system(size: 20, weight: .medium, design: .rounded))
                .foregroundColor(.PrimaryText)

            Text(String(localized: "This action cannot be undone."))
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundColor(.SubtitleText)
                .padding(.bottom, 15)
        }
    }

    @ViewBuilder
    var closeButtonIcon: some View {
        Image(systemName: "xmark")
            .font(.system(.subheadline, design: .rounded).weight(.semibold))
            .dynamicTypeSize(...DynamicTypeSize.xxLarge)
            .foregroundColor(Color.SubtitleText)
            .padding(7)
            .background(Color.SecondaryBackground, in: Circle())
            .contentShape(Circle())
    }

    @ViewBuilder
    var deleteButtonIcon: some View {
        Image(systemName: "trash.fill")
            .font(.system(.subheadline, design: .rounded).weight(.semibold))
            .dynamicTypeSize(...DynamicTypeSize.xxLarge)
            .foregroundColor(Color.AlertRed)
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
                .accessibilityLabel("delete transaction")
            }

            Button {
                showRecurring = true
            } label: {
                if repeatType > 0 {
                    repeatIconWithOverlay
                } else {
                    Image(systemName: "repeat")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color.SubtitleText)
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
                        .foregroundColor(Color.AlertRed)

                    Text(toastTitle)
                        .font(.system(.body, design: .rounded).weight(.semibold))
                        .lineLimit(1)
                        .foregroundColor(Color.AlertRed)
                }
                .padding(8)
                .background(
                    Color.AlertRed.opacity(0.23),
                    in: RoundedRectangle(cornerRadius: 9, style: .continuous)
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
    var swipeAndNumberPadArea: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                NumberPadTextView(vm: padVM, currencySymbol: currencySymbol)
                NoteView(note: $note, focused: $textFieldFocused)
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

            DatePicker(String(localized: "Date"), selection: $date)
                .datePickerStyle(.graphical)
                .padding(.horizontal, 15)
                .padding(.vertical, 8)
                .glassCard(in: RoundedRectangle(cornerRadius: 13))
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
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
                    if #available(iOS 17.0, *) {
                        Image(systemName: "rays")
                            .symbolEffect(
                                .variableColor.iterative.dimInactiveLayers.nonReversing,
                                options: .repeating, value: animateIcon)
                    } else {
                        Image(systemName: "slowmo")
                            .foregroundColor(Color.SubtitleText)
                    }
                }
            }
            .foregroundColor(Color.SubtitleText)
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
        .foregroundColor(Color.PrimaryText)
        .padding(.vertical, 8.5)
        .padding(.horizontal, 10)
        .animation(.default, value: isDateToday(date: date))
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(
            RoundedRectangle(cornerRadius: 11.5, style: .continuous)
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
                        Text(String(localized: "Close"))
                            .font(.system(.body, design: .rounded).weight(.semibold))
                            .lineLimit(1)
                    }
                    .padding(.vertical, 8.5)
                    .padding(.horizontal, 10)
                    .frame(width: widthOfCategoryButton)
                    .foregroundColor(Color.AlertRed)
                    .background(Color.AlertRed.opacity(0.23),
                        in: RoundedRectangle(cornerRadius: 11.5, style: .continuous)
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
        .foregroundColor(color)
        .background(
            color.opacity(0.35),
            in: RoundedRectangle(cornerRadius: 11.5, style: .continuous)
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

            Text(String(localized: "Category"))
                .font(.system(.body, design: .rounded).weight(.semibold))
                .lineLimit(1)
        }
        .padding(.vertical, 8.5)
        .padding(.horizontal, 10)
        .foregroundColor(categoryButtonTextColor)
        .background(
            categoryButtonBackgroundColor,
            in: RoundedRectangle(cornerRadius: 11.5, style: .continuous)
        )
        .contentShape(Rectangle())
        .overlay(
            RoundedRectangle(cornerRadius: 11.5, style: .continuous)
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
            if #available(iOS 17.0, *) {
                Image(systemName: "circle.grid.2x2")
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .symbolEffect(
                        .bounce.up.byLayer, options: .repeating.speed(0.5),
                        value: showCategoryPicker)
            } else {
                Image(systemName: "circle.grid.2x2")
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
            }

            Text(String(localized: "Category"))
                .font(.system(.body, design: .rounded).weight(.semibold))
                .lineLimit(1)
        }
        .padding(.vertical, 8.5)
        .padding(.horizontal, 10)
        .frame(width: widthOfCategoryButton)
        .foregroundColor(categoryButtonTextColor)
        .background(
            categoryButtonBackgroundColor,
            in: RoundedRectangle(cornerRadius: 11.5, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 11.5, style: .continuous)
                .strokeBorder(categoryButtonOutlineColor, lineWidth: 1.5)
        )
        .drawingGroup()
    }

    @ViewBuilder
    var expenseToggleButton: some View {
        Text(String(localized: "Expense"))
            .font(.system(.body, design: .rounded).weight(.semibold))
            .lineLimit(1)
            .foregroundColor(income == false ? Color.PrimaryText : Color.SubtitleText)
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
        Text(String(localized: "transaction-view-income-picker"))
            .font(.system(.body, design: .rounded).weight(.semibold))
            .lineLimit(1)
            .foregroundColor(income == true ? Color.PrimaryText : Color.SubtitleText)
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
        dateFormatter.dateFormat = "d MMM yyyy"
        return dateFormatter.string(from: date)
    }

    var repeatButtonAccessibility: String {
        if repeatType == 1 {
            return String(localized: "transaction recurs daily, button to edit recurring duration")
        } else if repeatType == 2 {
            return String(localized: "transaction recurs weekly, button to edit recurring duration")
        } else if repeatType == 3 {
            return String(localized: "transaction recurs monthly, button to edit recurring duration")
        } else {
            return String(localized: "button to make transaction recurring")
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
                    deleteButtonLabel(String(localized: "Delete"), color: Color.AlertRed)
                }
                .padding(.bottom, 8)

                Button {
                    withAnimation(.easeOut(duration: 0.7)) {
                        deleteMode = false
                        toDelete = nil
                    }

                } label: {
                    cancelButtonLabel(String(localized: "Cancel"))
                }
            }
            .padding(13)
            .glassCard(in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 13).stroke(
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

    @AppStorage("colourScheme", store: UserDefaults(suiteName: "group.com.rafaelsoh.dime"))
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
        "showTransactionRecommendations", store: UserDefaults(suiteName: "group.com.rafaelsoh.dime"))
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
    @AppStorage("numberEntryType", store: UserDefaults(suiteName: "group.com.rafaelsoh.dime"))
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
            .frame(width: proxy.size.width, height: proxy.size.height)
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
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    showToast = false
                }
            }
        }
        .onChange(of: income) { _, _ in
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
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
                        padVM.decimalValuesAssigned = .second
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
        .sheet(isPresented: $showPicker) {
            if #available(iOS 16.0, *) {
                CustomRecurringView(
                    repeatType: $repeatType, repeatCoefficient: $repeatCoefficient, showPicker: $showPicker
                )
                .presentationDetents([.height(230)])
            } else {
                CustomRecurringView(
                    repeatType: $repeatType, repeatCoefficient: $repeatCoefficient, showPicker: $showPicker)
            }
        }
        .onChange(of: dynamicTypeSize) { _, _ in
            if income {
                swipingOffset = capsuleWidth
            }
        }
    }

    func isDateToday(date: Date) -> Bool {
        let calendar = Calendar.current

        return calendar.isDateInToday(date)
    }

    func getDateString(date: Date) -> String {
        let formatter = DateFormatter()

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
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
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

    func submit() {
        let generator = UINotificationFeedbackGenerator()
        let amount = padVM.price

        if amount == 0 && category == nil {
            toastImage = "questionmark.app"
            toastTitle = String(localized: "Incomplete Entry")
            showToast = true
            toggleFieldColors()

            generator.notificationOccurred(.error)

            return
        } else if amount == 0 {
            toastImage = "centsign.circle"
            toastTitle = String(localized: "Missing Amount")
            showToast = true
            generator.notificationOccurred(.error)
            return
        } else if category == nil {
            toastImage = "tray"
            toastTitle = String(localized: "Missing Category")
            showToast = true

            toggleFieldColors()

            generator.notificationOccurred(.error)
            return
        }

        generator.notificationOccurred(.success)

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

struct NumPadButton: ButtonStyle {
    public func makeBody(configuration: Self.Configuration) -> some View {
        return configuration.label
            .scaleEffect(configuration.isPressed ? 0.8 : 1)
            .animation(.easeOut(duration: 0.3), value: configuration.isPressed)
            .opacity(configuration.isPressed ? 0.5 : 1)
    }
}

func getDollarOffset(big: CGFloat, small: CGFloat) -> CGFloat {
    let bigFont = UIFont.rounded(ofSize: big, weight: .regular)
    let smallFont = UIFont.rounded(ofSize: small, weight: .light)

    return bigFont.capHeight - smallFont.capHeight - 1
}

struct NoteView: View {
    @Binding var note: String
    @Binding var focused: Bool

    @FocusState private var textFocused: Bool
    let characterLimit = 50

    @Environment(\.dynamicTypeSize) var dynamicTypeSize

    var noteWidth: CGFloat {
        let fontSize: CGFloat = UIFont.getBodyFontSize(dynamicTypeSize: dynamicTypeSize)
        //        let fontSize: CGFloat = fontSize
        let systemFont = UIFont.systemFont(ofSize: fontSize, weight: .semibold)
        let roundedFont: UIFont
        if let descriptor = systemFont.fontDescriptor.withDesign(.rounded) {
            roundedFont = UIFont(descriptor: descriptor, size: fontSize)
        } else {
            roundedFont = systemFont
        }

        let attributes = [NSAttributedString.Key.font: roundedFont]

        let size = (note as NSString).size(withAttributes: attributes)

        let placeholder = String(localized: "Add Note")
        let placeholderSize = (placeholder as NSString).size(withAttributes: attributes)

        if !note.isEmpty {
            return size.width + 2
        } else {
            return placeholderSize.width
        }

        //        return max(size.width + 2, (placeholderSize.width + 1))
    }

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: "text.alignleft")
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            //                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color.SubtitleText)

            ZStack(alignment: .leading) {
                TextField("", text: $note)
                    .onReceive(Just(note)) { _ in limitText(characterLimit) }
                    .focused($textFocused)
                    .foregroundColor(Color.PrimaryText)

                if note.isEmpty {
                    Text(String(localized: "Add Note"))
                        .foregroundColor(Color.SubtitleText)
                }
            }
            .font(.system(.body, design: .rounded).weight(.semibold))
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            //            .font(.system(size: 16, weight: .semibold, design: .rounded))
            .frame(width: min(noteWidth, ScreenSize.width / 1.5), alignment: .center)
        }
        .onTapGesture {
            textFocused = true
        }
        .padding(.vertical, 7)
        .padding(.horizontal, 10)
        .overlay(
            RoundedRectangle(cornerRadius: 11.5, style: .continuous)
                .stroke(Color.Outline, lineWidth: 1.5)
        )
        .onChange(of: textFocused) { _, newValue in
            focused = newValue
        }
    }

    func limitText(_ upper: Int) {
        if note.count > upper {
            note = String(note.prefix(upper))
        }
    }
}

struct RecurringPickerView: View {
    @Namespace var animation
    @Binding var repeatType: Int
    @Binding var repeatCoefficient: Int
    @Binding var showMenu: Bool

    @Binding var showPicker: Bool

    let stringArray = ["none", "daily", "weekly", "monthly"]
    let stringArray2 = ["", "days", "weeks", "months"]

    @AppStorage("bottomEdge", store: UserDefaults(suiteName: "group.com.rafaelsoh.dime"))
    var bottomEdge: Double = 15

    @State private var offset: CGFloat = 0

    @State var holdingType = 0
    @State var holdingCoefficient = 0

    @AppStorage("colourScheme", store: UserDefaults(suiteName: "group.com.rafaelsoh.dime"))
    var colourScheme: Int = 0

    @Environment(\.colorScheme) var systemColorScheme

    var darkMode: Bool {
        (colourScheme == 0 && systemColorScheme == .dark) || colourScheme == 2
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            ForEach(stringArray, id: \.self) { string in
                HStack {
                    Text(LocalizedStringKey(string))
                        .font(.system(.body, design: .rounded).weight(.medium))
                        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                        .lineLimit(1)
                    Spacer()

                    if repeatType == (stringArray.firstIndex(of: string) ?? 0) && repeatCoefficient == 1 {
                        Image(systemName: "checkmark")
                            .font(.system(.footnote, design: .rounded).weight(.medium))
                            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                        //                            .font(.system(size: 14, weight: .medium))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                //                .font(.system(size: 18, weight: .medium, design: .rounded))
                .padding(5)
                .background {
                    if repeatType == (stringArray.firstIndex(of: string) ?? 0) && repeatCoefficient == 1 {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(
                                darkMode
                                ? Color("AlwaysDarkSecondaryBackground") : Color("AlwaysLightSecondaryBackground")
                            )
                            .matchedGeometryEffect(id: "TAB", in: animation)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    if repeatType == (stringArray.firstIndex(of: string) ?? 0) && repeatCoefficient == 1 {
                        showMenu = false
                    } else {
                        withAnimation(.easeIn(duration: 0.15)) {
                            repeatType = (stringArray.firstIndex(of: string) ?? 0)
                            repeatCoefficient = 1
                        }

                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                            showMenu = false
                        }
                    }
                }
            }

            HStack {
                if repeatCoefficient == 1 {
                    Text(String(localized: "custom"))
                } else {
                    if repeatType == 1 {
                        Text("\(repeatCoefficient) \(String(localized: "days"))")
                    } else if repeatType == 2 {
                        Text("\(repeatCoefficient) \(String(localized: "weeks"))")
                    } else if repeatType == 3 {
                        Text("\(repeatCoefficient) \(String(localized: "months"))")
                    }
                }

                Spacer()

                if repeatCoefficient > 1 {
                    Image(systemName: "checkmark")
                        .font(.system(.footnote, design: .rounded).weight(.medium))
                        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                    //                        .font(.system(size: 14, weight: .medium))
                }
            }
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
            .font(.system(.body, design: .rounded).weight(.medium))
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            //            .font(.system(size: 18, weight: .medium, design: .rounded))
            .padding(5)
            .background {
                if repeatCoefficient > 1 {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            darkMode
                            ? Color("AlwaysDarkSecondaryBackground") : Color("AlwaysLightSecondaryBackground")
                        )
                        .matchedGeometryEffect(id: "TAB", in: animation)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                if repeatCoefficient == 1 {
                    repeatCoefficient = 2
                    repeatType = 2

                    holdingType = repeatType
                    holdingCoefficient = repeatCoefficient
                }

                withAnimation {
                    showPicker = true
                }
            }
            .onChange(of: showPicker) { _, newValue in
                // holdingType != repeatType || holdingCoefficient != repeatCoefficient
                if !newValue {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        showMenu = false
                    }
                }
            }
        }
        .foregroundColor(darkMode ? Color("AlwaysLightBackground") : Color("AlwaysDarkBackground"))
        .padding(4)
        .frame(width: 150)
        .background(
            RoundedRectangle(cornerRadius: 9).fill(
                darkMode ? Color("AlwaysDarkBackground") : Color("AlwaysLightBackground")
            ).shadow(color: darkMode ? Color.clear : Color.gray.opacity(0.25), radius: 6)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 9).stroke(
                darkMode ? Color.gray.opacity(0.1) : Color.clear, lineWidth: 1.3))
    }
}

struct CustomRecurringView: View {
    @Binding var repeatType: Int
    @Binding var repeatCoefficient: Int
    @Binding var showPicker: Bool

    @Environment(\.colorScheme) var systemColorScheme
    var stringArray: [String] {
        return [
            "", "\(holdingCoefficient) days", "\(holdingCoefficient) weeks",
            "\(holdingCoefficient) months"
        ]
    }

    @Environment(\.dismiss) var dismiss

    @State var holdingType = 0
    @State var holdingCoefficient = 0

    var body: some View {
        VStack(spacing: 35) {
            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                    //                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color.SubtitleText)
                        .padding(7)
                        .background(Color.SecondaryBackground, in: Circle())
                        .contentShape(Circle())
                }

                Spacer()

                Text(String(localized: "Custom Interval"))
                    .font(.system(.body, design: .rounded).weight(.semibold))
                    .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                //                    .font(.system(size: 18, weight: .semibold, design: .rounded))

                Spacer()

                Button {
                    repeatType = holdingType
                    repeatCoefficient = holdingCoefficient

                    UIImpactFeedbackGenerator(style: .light).impactOccurred()

                    dismiss()

                } label: {
                    Image(systemName: "checkmark")
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                    //                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color.IncomeGreen)
                        .padding(7)
                        .background(Color.IncomeGreen.opacity(0.23), in: Circle())
                        .contentShape(Circle())
                }
            }

            HStack(spacing: 10) {
                Text(String(localized: "Repeats every"))
                    .font(.system(size: 23, weight: .medium, design: .rounded))
                    .foregroundColor(Color.PrimaryText)
                    .padding(.trailing, 3)

                VStack {
                    Button {
                        holdingCoefficient += 1
                    } label: {
                        Image(systemName: "chevron.up")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color.SubtitleText)
                            .padding(7)
                            .background(
                                Color.SecondaryBackground, in: RoundedRectangle(cornerRadius: 6, style: .continuous)
                            )
                            .contentShape(Circle())
                            .opacity(holdingCoefficient == 30 ? 0.25 : 1)
                    }
                    .disabled(holdingCoefficient == 30)

                    Text("\(holdingCoefficient)")
                        .font(.system(size: 23, weight: .medium, design: .rounded))
                        .padding(7)
                        .background {
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .fill(Color.SecondaryBackground)
                                .frame(width: 40, height: 40)
                        }

                    Button {
                        holdingCoefficient -= 1
                    } label: {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color.SubtitleText)
                            .padding(7)
                            .background(
                                Color.SecondaryBackground, in: RoundedRectangle(cornerRadius: 6, style: .continuous)
                            )
                            .contentShape(Circle())
                            .opacity(holdingCoefficient == 2 ? 0.25 : 1)
                    }
                    .disabled(holdingCoefficient == 2)
                }

                VStack {
                    Button {
                        holdingType -= 1
                    } label: {
                        Image(systemName: "chevron.up")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color.SubtitleText)
                            .padding(7)
                            .background(
                                Color.SecondaryBackground, in: RoundedRectangle(cornerRadius: 6, style: .continuous)
                            )
                            .contentShape(Circle())
                            .opacity(holdingType == 1 ? 0.25 : 1)
                    }
                    .disabled(holdingType == 1)

                    Group {
                        if holdingType == 1 {
                            Text(String(format: String(localized: "%lld days"), holdingCoefficient))
                        } else if holdingType == 2 {
                            Text(String(format: String(localized: "%lld weeks"), holdingCoefficient))
                        } else if holdingType == 3 {
                            Text(String(format: String(localized: "%lld months"), holdingCoefficient))
                        }
                    }
                    .font(.system(size: 23, weight: .medium, design: .rounded))
                    .padding(7)
                    .background {
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(Color.SecondaryBackground)
                            .frame(height: 40)
                    }

                    Button {
                        holdingType += 1
                    } label: {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color.SubtitleText)
                            .padding(7)
                            .background(
                                Color.SecondaryBackground, in: RoundedRectangle(cornerRadius: 6, style: .continuous)
                            )
                            .contentShape(Circle())
                            .opacity(holdingType == 3 ? 0.25 : 1)
                    }
                    .disabled(holdingType == 3)
                }
            }
            .padding(.bottom, 20)
        }
        .padding(13)
        .frame(maxHeight: .infinity, alignment: .top)
        .onAppear {
            holdingType = repeatType
            holdingCoefficient = repeatCoefficient
        }
    }
}

struct ButtonView: View {
    let number: Int
    let size: CGSize

    var body: some View {
        Text("\(number)")
            .font(.system(size: 34, weight: .regular, design: .rounded))
            .frame(width: size.width * 0.3, height: size.height * 0.22)
            .background(Color.SecondaryBackground)
            .foregroundColor(Color.PrimaryText)
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
