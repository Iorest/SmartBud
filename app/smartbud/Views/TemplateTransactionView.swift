//
//  TemplateTransactionView.swift
//  smartbud
//
//  Created by Iorest on 4/9/23.
//

import Foundation
import SwiftUI
import WidgetKit

struct TemplateTransactionView: View {
    @Environment(TransactionViewModel.self) var transactionVM
    @Environment(CategoryViewModel.self) var categoryVM
    @Environment(\.dismiss) var dismiss

    @AppStorage("numberEntryType", store: .appGroup) var numberEntryType: Int = 1

    @Environment(\.colorScheme) var colorScheme

    @AppStorage("topEdge", store: .appGroup) var topEdge: Double = 30

    @State private var note = ""
    @State var category: CategoryModel?
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

    @State private var numbers: [Int] = [0, 0, 0]
    @State private var numbers1: [String] = []
    private var amount: String {
        var string = ""

        if numberEntryType == 1 {
            for i in numbers.indices {
                if i == (numbers.count - 2) {
                    string += ".\(numbers[i])"
                } else {
                    string += "\(numbers[i])"
                }
            }

            return string
        } else {
            if numbers1.isEmpty {
                return "0"
            }
            for i in numbers1 {
                string = string + i
            }

            return string
        }
    }

    var transactionValue: Double {
        return (amount as NSString).doubleValue
    }

    @State var showCategoryPicker = false
    @State var showCategorySheet = false

    @AppStorage("currency", store: .appGroup) var currency: String = Locale.current.currency?.identifier ?? "USD"
    var currencySymbol: String {
        return Locale.appCurrencySymbol(forCurrencyCode: currency)
    }

    @State var showingCategoryView = false

    // toasts
    @State var showToast = false
    @State var toastTitle = ""
    @State var toastImage = ""

    // sensory feedback triggers
    @State private var errorHaptic = 0
    @State private var successHaptic = 0

    @AppStorage("firstTransactionViewLaunch", store: .appGroup) var firstLaunch: Bool = true

    // edit mode
    let toEdit: TemplateTransactionModel?

    // delete mode

    @State var toDelete: TemplateTransactionModel?
    @State var deleteMode = false

    @AppStorage("bottomEdge", store: .appGroup) var bottomEdge: Double = 15

    @State private var offset: CGFloat = 0

    let repeatOverlays = ["D", "W", "M"]
    let numberArray = [[1, 2, 3], [4, 5, 6], [7, 8, 9]]
    var numberArrayCount: Int {
        if numberEntryType == 1 {
            return numbers.count
        } else {
            return numbers1.count
        }
    }

    var downsize: (big: CGFloat, small: CGFloat) {
        let amountText: String
        let size = ScreenSize.width - 105

        if numberEntryType == 2 {
            amountText = amount
        } else {
            amountText = transactionValue.formatted(.number.precision(.fractionLength(2)))
        }

        if (amountText.widthOfRoundedString(size: 32, weight: .regular) + currencySymbol.widthOfRoundedString(size: 20, weight: .light) + 4) > size {
            return (24, 16)
        } else if (amountText.widthOfRoundedString(size: 44, weight: .regular) + currencySymbol.widthOfRoundedString(size: 25, weight: .light) + 4) > size {
            return (32, 20)
        } else if (amountText.widthOfRoundedString(size: 56, weight: .regular) + currencySymbol.widthOfRoundedString(size: 32, weight: .light) + 4) > size {
            return (44, 25)
        } else {
            return (56, 32)
        }
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

    @AppStorage("colourScheme", store: .appGroup) var colourScheme: Int = 0

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

    let order: Int

    @Namespace var animation

    var body: some View {
//        ScrollView {
        GeometryReader { proxy in
            VStack(spacing: 8) {
                // income/expense picker
                VStack {
                    if showToast {
                        HStack(spacing: 6.5) {
                            Image(systemName: toastImage)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Color.AlertRed)

                            Text(toastTitle)
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundStyle(Color.AlertRed)
                        }
                        .padding(8)
                        .background(Color.AlertRed.opacity(0.23), in: RoundedRectangle(cornerRadius: GlassRadius.chip, style: .continuous))
                        .transition(AnyTransition.opacity.combined(with: .move(edge: .top)))
                        .frame(maxWidth: 200)
                    } else {
                        HStack(spacing: 0) {
                            Text("Expense")
                                .font(.system(size: 18, weight: .semibold, design: .rounded))
                                .foregroundStyle(income == false ? Color.PrimaryText : Color.SubtitleText)
                                .padding(6)
                                .padding(.horizontal, 8)
                                .background {
                                    if income == false {
                                        Capsule()
                                            .fill(Color.SecondaryBackground)
                                            .matchedGeometryEffect(id: "TAB1", in: animation)
                                    }
                                }
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    withAnimation(.easeIn(duration: 0.15)) {
                                        income = false
                                        category = nil
                                    }

                                }

                            Text("transaction-view-income-picker")
                                .font(.system(size: 18, weight: .semibold, design: .rounded))
                                .foregroundStyle(income == true ? Color.PrimaryText : Color.SubtitleText)
                                .padding(6)
                                .padding(.horizontal, 8)
                                .background {
                                    if income == true {
                                        Capsule()
                                            .fill(Color.SecondaryBackground)
                                            .matchedGeometryEffect(id: "TAB1", in: animation)
                                    }
                                }
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    withAnimation(.easeIn(duration: 0.15)) {
                                        income = true
                                        category = nil
                                    }

                                }
                        }
                        .padding(3)
                        .overlay(Capsule().stroke(Color.Outline.opacity(0.4), lineWidth: 1.3))
                    }
                }
                .frame(height: 35)
                .frame(maxWidth: .infinity)
                .overlay {
                    HStack {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Color.SubtitleText)
                                .padding(7)
                                .background(Color.SecondaryBackground, in: Circle())
                                .contentShape(Circle())
                        }

                        Spacer()

                        if toEdit != nil {
                            Button {
                                toDelete = toEdit
                                deleteMode = true

                            } label: {
                                Image(systemName: "trash.fill")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(Color.AlertRed)
                                    .padding(7)
                                    .background(Color.AlertRed.opacity(0.23), in: Circle())
                                    .contentShape(Circle())
                            }
                            .accessibilityLabel(String.appLocalized("delete transaction"))
                        }

                        Button {
                            showRecurring = true
                        } label: {
                            if repeatType > 0 {
                                Image(systemName: "repeat")
                                    .font(.system(size: 16, weight: .semibold))
                                    .overlay(alignment: .topTrailing) {
                                        Text(repeatOverlays[repeatType - 1])
                                            .font(.system(size: 6, weight: .black, design: .rounded))
                                            .foregroundStyle(Color.IncomeGreen)
                                            .frame(width: 10, alignment: .leading)
                                            .offset(x: 5.7, y: 1.5)
                                    }
                                    .foregroundStyle(Color.IncomeGreen)
                                    .padding(7)
                                    .background(Color.IncomeGreen.opacity(0.23), in: Circle())
                                    .contentShape(Circle())
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
                            RecurringPickerView(repeatType: $repeatType, repeatCoefficient: $repeatCoefficient, showMenu: $showRecurring, showPicker: $showPicker)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.top, topEdge)

                // number display and note view
                VStack(spacing: 8) {
                    if numberEntryType == 1 {
                        HStack(alignment: .lastTextBaseline, spacing: 4) {
                            Text(currencySymbol)
                                .font(.system(size: downsize.small, weight: .light, design: .rounded))
                                .foregroundStyle(Color.SubtitleText)
                                .baselineOffset(getDollarOffset(big: downsize.big, small: downsize.small))
                            Text(transactionValue, format: .number.precision(.fractionLength(2)))
                                .font(.system(size: downsize.big, weight: .regular, design: .rounded))
                                .foregroundStyle(Color.PrimaryText)
                        }
                    } else {
                        if numbers1.isEmpty {
                            HStack(alignment: .lastTextBaseline, spacing: 4) {
                                Text(currencySymbol)
                                    .font(.system(size: 32, weight: .light, design: .rounded))
                                    .foregroundStyle(Color.SubtitleText)
                                    .baselineOffset(getDollarOffset(big: 56, small: 32))
                                Text("0")
                                    .font(.system(size: 56, weight: .regular, design: .rounded))
                                    .foregroundStyle(Color.PrimaryText)
                            }
                            .frame(maxWidth: .infinity)
                        } else {
                            HStack(alignment: .lastTextBaseline, spacing: 4) {
                                Text(currencySymbol)
                                    .font(.system(size: downsize.small, weight: .light, design: .rounded))
                                    .foregroundStyle(Color.SubtitleText)
                                    .baselineOffset(getDollarOffset(big: downsize.big, small: downsize.small))
                                Text(amount)
                                    .font(.system(size: downsize.big, weight: .regular, design: .rounded))
                                    .foregroundStyle(Color.PrimaryText)
                            }
                            .frame(maxWidth: .infinity)
                            .overlay(alignment: .trailing) {
                                DeleteButton()
                            }
                        }
                    }

                    NoteView(note: $note, focused: Binding.constant(false))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // date and category picker
                CategoryRowPickerView(category: $category, income: income)
                    .padding(.bottom, 5)

                // num pad
                GeometryReader { proxy in
                    VStack(spacing: proxy.size.height * 0.04) {
                        ForEach(numberArray, id: \.self) { array in
                            HStack(spacing: proxy.size.width * 0.05) {
                                ForEach(array, id: \.self) { singleNumber in
                                    NumberButton(number: singleNumber, size: proxy.size)
                                }
                            }
                        }

                        HStack(spacing: proxy.size.width * 0.05) {
                            if numberEntryType == 1 {
                                Button {
                                    if numbers.count == 3 {
                                        numbers.remove(at: numbers.count - 1)
                                        numbers.insert(0, at: 0)
                                    } else {
                                        numbers.remove(at: numbers.count - 1)
                                    }
                                } label: {
                                    Image("tag-cross")
                                        .resizable()
                                        .frame(width: 32, height: 32)
                                        .frame(width: proxy.size.width * 0.3, height: proxy.size.height * 0.22)
                                        .background(Color.DarkBackground)
                                        .foregroundStyle(Color.LightIcon)
                                        .clipShape(RoundedRectangle(cornerRadius: GlassRadius.chip, style: .continuous))
                                }
                                .buttonStyle(NumPadButton())
                            } else {
                                Button {
                                    if numbers1.isEmpty {
                                        numbers1.append("0")
                                        numbers1.append(".")
                                    } else if numbers1.contains(".") {
                                        return
                                    } else {
                                        numbers1.append(".")
                                    }
                                } label: {
                                    Text(".")
                                        .font(.system(size: 34, weight: .regular, design: .rounded))
                                        .frame(width: proxy.size.width * 0.3, height: proxy.size.height * 0.22)
                                        .background(Color.SecondaryBackground)
                                        .foregroundStyle(Color.PrimaryText)
                                        .clipShape(RoundedRectangle(cornerRadius: GlassRadius.chip, style: .continuous))
                                        .opacity(numbers1.contains(".") ? 0.6 : 1)
                                }
                                .disabled(numbers1.contains("."))
                                .buttonStyle(NumPadButton())
                            }

                            NumberButton(number: 0, size: proxy.size)

                            let canSubmit = transactionValue != 0
                            Button {
                                submit()
                            } label: {
                                Group {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 30, weight: .semibold, design: .rounded))
                                            .symbolEffect(.bounce.up.byLayer, value: canSubmit)
//                                            .symbolEffectsRemoved()
                                }
                                .frame(width: proxy.size.width * 0.3, height: proxy.size.height * 0.22)
                                .foregroundStyle(Color.LightIcon)
                                .background(Color.accentColor.opacity(canSubmit ? 1 : 0.4), in: RoundedRectangle(cornerRadius: GlassRadius.chip, style: .continuous))
                            }
                            .buttonStyle(NumPadButton())
                            .disabled(!canSubmit)
                        }
                    }
                    .frame(width: proxy.size.width, height: proxy.size.height)
                }
                .padding(.bottom, 15)
//                .keyboardAwareHeight()
            }
            .padding(17)
            .frame(width: proxy.size.width, height: proxy.size.height)
            .background(Color.clear)
            .onTapGesture {
                self.hideKeyboard()
            }
            .fullScreenCover(isPresented: $deleteMode) {
                ZStack(alignment: .bottom) {
                    Color.clear
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            deleteMode = false
                            toDelete = nil
                        }

                    VStack(alignment: .leading, spacing: 1.5) {
                        Text("Delete Expense?")
                            .font(.system(size: 20, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.PrimaryText)

                        Text("This action cannot be undone.")
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.SubtitleText)
                            .padding(.bottom, 15)

                        Button {
                            deleteMode = false

                            withAnimation {
                                if let itemToDelete = toDelete {
                                    transactionVM.deleteTemplate(itemToDelete)
                                }
                            }

                            dismiss()

                        } label: {
                            Text(String.appLocalized("Delete"))
                                .font(.system(size: 20, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white)
                                .frame(height: 45)
                                .frame(maxWidth: .infinity)
                                .background(Color.AlertRed, in: RoundedRectangle(cornerRadius: GlassRadius.chip, style: .continuous))
                        }
                        .padding(.bottom, 8)

                        Button {
                            withAnimation(.easeOut(duration: 0.7)) {
                                deleteMode = false
                                toDelete = nil
                            }

                        } label: {
                            Text(String.appLocalized("Cancel"))
                                .font(.system(size: 20, weight: .semibold, design: .rounded))
                                .foregroundStyle(Color.PrimaryText.opacity(0.9))
                                .frame(height: 45)
                                .frame(maxWidth: .infinity)
                                .background(Color.SecondaryBackground, in: RoundedRectangle(cornerRadius: GlassRadius.chip, style: .continuous))
                        }
                    }
                    .padding(13)
                    .glassCard(in: RoundedRectangle(cornerRadius: GlassRadius.card, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: GlassRadius.card).stroke(systemColorScheme == .dark ? Color.gray.opacity(0.1) : Color.clear, lineWidth: 1.3))
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
        }
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
        .onAppear {
            categoryVM.load()
            if let transaction = toEdit {
                let string = transaction.wrappedAmount.formatted(.number.precision(.fractionLength(2)))

                var stringArray = string.compactMap { String($0) }

                numbers = stringArray.compactMap { Int($0) }

                if round(transaction.wrappedAmount) == transaction.wrappedAmount {
                    stringArray.removeLast()
                    stringArray.removeLast()
                    stringArray.removeLast()
                    numbers1 = stringArray
                } else {
                    numbers1 = stringArray
                }
            }

        }
        .sheet(isPresented: $showCategorySheet) {
            CategoryView(mode: .transaction, income: income)
        }
        .sheet(isPresented: $showPicker) {
                CustomRecurringView(repeatType: $repeatType, repeatCoefficient: $repeatCoefficient, showPicker: $showPicker)
                    .presentationDetents([.height(230)])
        }
        .sensoryFeedback(.error, trigger: errorHaptic)
        .sensoryFeedback(.success, trigger: successHaptic)
    }

    @ViewBuilder
    func DeleteButton() -> some View {
        Button {
            if !numbers1.isEmpty {
                if numbers1.count == 2 && numbers1[0] == "0" && numbers1[1] == "." {
                    numbers1.removeAll()
                } else {
                    numbers1.removeLast()
                }
            }

        } label: {
            Image(systemName: "delete.left.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.SubtitleText)
                .padding(7)
                .background(Color.SecondaryBackground, in: Circle())
                .contentShape(Circle())
        }
        .disabled(numbers1.isEmpty)
    }

    @ViewBuilder
    func NumberButton(number: Int, size: CGSize) -> some View {
        Button {
            if numberEntryType == 1 {
                if numbers[0] == 0 {
                    numbers.append(number)
                    numbers.remove(at: 0)
                } else {
                    numbers.append(number)
                }
            } else {
                if number == 0 && numbers1.isEmpty {
                    return
                } else {
                    if numbers1.contains(".") {
                        if numbers1.count - numbers1.firstIndex(of: ".")! < 3 {
                            numbers1.append(String(number))
                        } else {
                            return
                        }
                    } else {
                        numbers1.append(String(number))
                    }
                }
            }
        } label: {
            Text("\(number)")
                .font(.system(size: 34, weight: .regular, design: .rounded))
                .frame(width: size.width * 0.3, height: size.height * 0.22)
                .background(Color.SecondaryBackground)
                .foregroundStyle(Color.PrimaryText)
                .clipShape(RoundedRectangle(cornerRadius: GlassRadius.chip, style: .continuous))
                .opacity(numberArrayCount == 9 ? 0.6 : 1)
        }
        .disabled(numberArrayCount == 9)
        .buttonStyle(NumPadButton())
    }

    func submit() {
        if transactionValue == 0 && category == nil {
            toastImage = "questionmark.app"
            toastTitle = "Incomplete Entry"
            showToast = true
            errorHaptic &+= 1

            return
        } else if transactionValue == 0 {
            toastImage = "centsign.circle"
            toastTitle = "Missing Amount"
            showToast = true
            errorHaptic &+= 1
            return
        } else if category == nil {
            toastImage = "tray"
            toastTitle = "Missing Category"
            showToast = true
            errorHaptic &+= 1
            return
        }

        successHaptic &+= 1

        if let editedTransaction = toEdit {
            if note.trimmingCharacters(in: .whitespacesAndNewlines) == "" {
                editedTransaction.note = category!.wrappedName
            } else {
                editedTransaction.note = note.trimmingCharacters(in: .whitespaces)
            }

            if let unwrappedCategory = category {
                editedTransaction.category = unwrappedCategory
            }

            editedTransaction.amount = transactionValue
            editedTransaction.income = income

            editedTransaction.recurringType = repeatType
            editedTransaction.recurringCoefficient = repeatCoefficient

            transactionVM.save()

            dismiss()

        } else {
            let resolvedNote: String
            if note.trimmingCharacters(in: .whitespacesAndNewlines) == "" {
                resolvedNote = category?.wrappedName ?? ""
            } else {
                resolvedNote = note.trimmingCharacters(in: .whitespaces)
            }

            transactionVM.createOrUpdateTemplate(
                order: order,
                note: resolvedNote,
                category: category,
                income: income,
                amount: transactionValue,
                repeatType: repeatType,
                repeatCoefficient: repeatCoefficient
            )

            dismiss()
        }

        WidgetCenter.shared.reloadAllTimelines()
    }

    init(order: Int) {

        let toEdit = TransactionViewModel.shared.getTemplate(order)

        if let transaction = toEdit {
            _note = State(initialValue: transaction.wrappedNote)

            if let unwrappedCategory = transaction.category {
                _category = State(initialValue: unwrappedCategory)
            }

            _income = State(initialValue: transaction.income)

            _repeatType = State(initialValue: transaction.recurringType)
            _repeatCoefficient = State(initialValue: transaction.recurringCoefficient)
        }

        self.order = order
        self.toEdit = toEdit
    }
}

struct CategoryRowPickerView: View {
    @Environment(CategoryViewModel.self) var categoryVM

    @Binding var selectedCategory: CategoryModel?
    @State var showCategorySheet = false
    let income: Bool

    var empty: Bool {
        if income {
            return categoryVM.incomeCategories.isEmpty
        } else {
            return categoryVM.expenseCategories.isEmpty
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            if empty {
                Text("No categories found")
                    .font(.system(size: 17.5, weight: .medium, design: .rounded))
                    .padding(.horizontal, 13)
                    .foregroundStyle(Color.SubtitleText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: 36)
                    .overlay(
                        RoundedRectangle(cornerRadius: GlassRadius.input, style: .continuous)
                            .stroke(Color.Outline, lineWidth: 1.5)
                    )

            } else {
                GeometryReader { gp in
                    ZStack {
                        ScrollView(.horizontal) {
                            ScrollViewReader { value in
                                HStack(spacing: 8) {
                                    ForEach(income ? categoryVM.incomeCategories : categoryVM.expenseCategories, id: \.self) { item in
                                        HStack(spacing: 5) {
                                            Text(item.wrappedEmoji)
                                                .font(.system(size: 13))
                                            Text(item.wrappedName)
                                                .font(.system(size: 17.5, weight: .medium, design: .rounded))
                                        }
                                        .id(item.id)
                                        .padding(.horizontal, 10)
                                        .frame(height: 36)
                                        .foregroundStyle(selectedCategory == item ? (item.income ? Color.IncomeGreen : Color(hex: item.wrappedColour)) : Color.PrimaryText)
                                        .background(getBackground(category: item), in: RoundedRectangle(cornerRadius: GlassRadius.chip, style: .continuous))
                                        .overlay {
                                            if selectedCategory != item {
                                                RoundedRectangle(cornerRadius: GlassRadius.chip, style: .continuous)
                                                    .strokeBorder(Color.Outline,
                                                                  style: StrokeStyle(lineWidth: 1.5))
                                            }
                                        }
                                        .onTapGesture {
                                            selectedCategory = item
                                            withAnimation {
                                                value.scrollTo(item.id, anchor: .leading)
                                            }
                                        }
                                    }
                                }
                                .onChange(of: income) { _, newValue in
                                    if newValue {
                                        if let firstCategory = categoryVM.incomeCategories.first {
                                            value.scrollTo(firstCategory.id, anchor: .leading)
                                        }
                                    } else {
                                        if let firstCategory = categoryVM.expenseCategories.first {
                                            value.scrollTo(firstCategory.id, anchor: .leading)
                                        }
                                    }
                                }
                                .onAppear {
                                    if let unwrappedCategory = selectedCategory {
                                        withAnimation {
                                            value.scrollTo(unwrappedCategory.id, anchor: .leading)
                                        }
                                    }
                                }
                            }
                        }
                        .scrollIndicators(.hidden)
                        .clipped()

                        // inject gradient at right side only
                        Rectangle()
                            .fill(
                                LinearGradient(gradient: Gradient(stops: [
                                    .init(color: Color.PrimaryBackground.opacity(0.01), location: 0),
                                    .init(color: Color.PrimaryBackground, location: 1)
                                ]), startPoint: .leading, endPoint: .trailing)
                            ).frame(width: 0.1 * gp.size.width)
                            .frame(maxWidth: .infinity, alignment: .trailing)

                            .allowsHitTesting(false) // << now works !!

                    }.fixedSize(horizontal: false, vertical: true)
                }
                .frame(height: 36)
                .frame(maxWidth: .infinity)
            }

            Group {
                if empty {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.SubtitleText)
                } else {
                    Image(systemName: "pencil")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.SubtitleText)
                }

//                        Text("Edit")
//                            .font(.system(size: 17.5, weight: .semibold, design: .rounded))
//                            .lineLimit(1)
            }
            .padding(.horizontal, 9)
            .frame(height: 36)
            .background(Color.SecondaryBackground, in: RoundedRectangle(cornerRadius: GlassRadius.chip, style: .continuous))
//                    .overlay(
//                        RoundedRectangle(cornerRadius: GlassRadius.input, style: .continuous)
//                            .stroke(Color.Outline, lineWidth: 1.5)
//                    )
            .onTapGesture {
                showCategorySheet = true
            }
        }
        .frame(maxWidth: .infinity)
        .sheet(isPresented: $showCategorySheet) {
            CategoryView(mode: .transaction, income: income)
        }
    }

    func getBackground(category: CategoryModel) -> Color {
        if category.income {
            if category == selectedCategory {
                return Color.IncomeGreen.opacity(0.3)
            } else {
                return Color.PrimaryBackground
            }
        } else {
            if category == selectedCategory {
                return Color(hex: category.wrappedColour).opacity(0.3)
            } else {
                return Color.PrimaryBackground
            }
        }
    }

    init(category: Binding<CategoryModel?>?, income: Bool) {
        _selectedCategory = category ?? Binding.constant(nil)
//        self.categories = categories
//        let dataController = DataController.shared
//        let fetchRequest = dataController.fetchRequestForCategories(income: income)
//        self.categories = dataController.results(for: fetchRequest)
        self.income = income
    }
}

struct SettingsQuickAddWidgetView: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 10) {
            Text("Quick Add Widget")
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.PrimaryText)
                .frame(maxWidth: .infinity)
                .overlay(alignment: .leading) {
                    Button {
                        dismiss()
                    } label: {
                        Circle()
                            .fill(Color.SecondaryBackground)
                            .frame(width: 30, height: 30)
                            .overlay {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(Color.SubtitleText)
                            }
                    }
                }
                .padding(.bottom, 40)

            SettingsQuickAddWidgetDraggingView()
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.PrimaryBackground)
    }
}

struct SettingsQuickAddWidgetDraggingView: View {
    @AppStorage("showCents", store: .appGroup) var showCents: Bool = true

    @AppStorage("currency", store: .appGroup) var currency: String = Locale.current.currency?.identifier ?? "USD"

    var currencySymbol: String {
        return Locale.appCurrencySymbol(forCurrencyCode: currency)
    }

    @State var gridData = GridViewModel()
    @State var selectedItem: Grid?
    @State var lastSelectedIndex: Int = 0

    @State var refreshID = UUID()

    let columns = Array(repeating: GridItem(.fixed(100), spacing: 15), count: 2)

    var body: some View {
        ZStack {
            LazyVGrid(columns: columns, spacing: 15, content: {
                ForEach(0 ..< 4) { index in

                    Image(systemName: "plus")
                        .font(.system(size: 25, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.SubtitleText)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(RoundedRectangle(cornerRadius: GlassRadius.card).fill(Color.SecondaryBackground).shadow(color: gridData.gridItems[index].transaction == nil ? Color.gray.opacity(0.25) : Color.clear, radius: 6))
                        .overlay(RoundedRectangle(cornerRadius: GlassRadius.card).stroke(Color.Outline, lineWidth: 1.3))
                        .frame(height: 100)
                }
            })

            LazyVGrid(columns: columns, spacing: 15, content: {
                ForEach(gridData.gridItems) { grid in

                    Group {
                        if let transaction = grid.transaction {
                            if grid.id == gridData.currentGrid?.id && gridData.dragging {
                                ZStack {
                                    RoundedRectangle(cornerRadius: GlassRadius.card)
                                        .fill(blend(over: Color(hex: transaction.wrappedColour), withAlpha: 0.7))

                                    RoundedRectangle(cornerRadius: GlassRadius.card)
                                        .strokeBorder(Color.DarkIcon, lineWidth: 2)
                                }
                            } else {
                                SingleTemplateButton(transaction: transaction, showCents: showCents, currencySymbol: currencySymbol)
                            }
                        } else {
                            Rectangle()
                                .fill(Color.clear)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .contentShape(Rectangle())
                        }
                    }
                    .frame(height: 100)
                    .transition(.opacity)
                    .contentShape(.dragPreview, RoundedRectangle(cornerRadius: GlassRadius.card))
                    .onDrag({
                        gridData.currentGrid = grid
                        return NSItemProvider(object: String(grid.index) as NSString)
                    }, preview: {
                        if let transaction = grid.transaction {
                            SingleTemplateButton(transaction: transaction, showCents: showCents, currencySymbol: currencySymbol)
                                .frame(width: 100, height: 100)
                                .contentShape(.dragPreview, RoundedRectangle(cornerRadius: GlassRadius.card))
                        }
                    })
                    .onDrop(of: [.text], delegate: DropViewDelegate(grid: grid, gridData: gridData))
                    .onTapGesture {
                        selectedItem = grid
                        lastSelectedIndex = grid.index
                    }
                }
            })
            .id(refreshID)
//
//            VStack {
//                ForEach(transactions) { transaction in
//                    Text(transaction.category?.wrappedName ?? "")
//                }
//            }
        }
        .padding(15)
        .frame(width: 245)
        .background(RoundedRectangle(cornerRadius: GlassRadius.surface).fill(Color.PrimaryBackground).shadow(color: Color.gray.opacity(0.2), radius: 12))
        .fullScreenCover(item: $selectedItem, onDismiss: {
            gridData.reset()
            refreshID = UUID()
        }) { grid in
            TemplateTransactionView(order: grid.index)
        }
    }
}

struct SingleTemplateButton: View {
    let transaction: TemplateTransactionModel
    let showCents: Bool
    let currencySymbol: String
    var dollarOffset: CGFloat {
        let bigFont = UIFont.rounded(ofSize: 21, weight: .semibold)
        let smallFont = UIFont.rounded(ofSize: 15, weight: .medium)

        return bigFont.capHeight - smallFont.capHeight
    }

    var downsize: (big: CGFloat, small: CGFloat, amountText: String) {
        let amountText: String
        let size: CGFloat = 80

        if showCents && transaction.amount < 100 {
            amountText = transaction.amount.formatted(.number.precision(.fractionLength(2)))
        } else {
            amountText = transaction.amount.formatted(.number.precision(.fractionLength(0)))
        }

        if amountText.widthOfRoundedString(size: 16, weight: .semibold) + currencySymbol.widthOfRoundedString(size: 13, weight: .medium) + 2 > size {
            return (12, 9, amountText)
        } else if amountText.widthOfRoundedString(size: 21, weight: .semibold) + currencySymbol.widthOfRoundedString(size: 18, weight: .medium) + 2 > size {
            return (16, 13, amountText)
        } else {
            return (21, 18, amountText)
        }
    }

    var transactionColor: Color {
        if transaction.category?.income ?? false {
            return Color.IncomeGreen
        } else {
            return Color(hex: transaction.wrappedColour)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: -2) {
            Text(transaction.wrappedEmoji)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .padding(5)
                .background(blend(over: transactionColor, withAlpha: 0.3), in: RoundedRectangle(cornerRadius: GlassRadius.chip))

            Spacer()

            Text(transaction.wrappedNote)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.PrimaryText)
                .lineLimit(1)

            HStack(alignment: .lastTextBaseline, spacing: 1.3) {
                Text(currencySymbol)
                    .font(.system(size: downsize.small, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.PrimaryText)
                    .baselineOffset(getDollarOffset(big: downsize.big, small: downsize.small))

                Text(downsize.amountText)
                    .font(.system(size: downsize.big, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.PrimaryText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .background(blend(over: transactionColor, withAlpha: 0.8), in: RoundedRectangle(cornerRadius: GlassRadius.card))
        .shadow(color: transactionColor.opacity(0.8), radius: 6)
    }

    func getDollarOffset(big: CGFloat, small: CGFloat) -> CGFloat {
        let bigFont = UIFont.rounded(ofSize: big, weight: .semibold)
        let smallFont = UIFont.rounded(ofSize: small, weight: .medium)

        return bigFont.capHeight - smallFont.capHeight
    }
}

@MainActor
struct Grid: Identifiable {
    var id: UUID
    var index: Int
    var transaction: TemplateTransactionModel?

    init(index: Int) {
        id = UUID()

        transaction = TransactionViewModel.shared.getTemplate(index)
        self.index = index
    }
}

@MainActor
@Observable
class GridViewModel {
    var currentGrid: Grid?
    var dragging = false

    var gridItems = [
        Grid(index: 0),
        Grid(index: 1),
        Grid(index: 2),
        Grid(index: 3)
    ]

    func reset() {
        withAnimation {
            gridItems = [
                Grid(index: 0),
                Grid(index: 1),
                Grid(index: 2),
                Grid(index: 3)
            ]
        }
    }

    func updateIndices() {
        for (index, element) in gridItems.enumerated() {
            if let transaction = element.transaction {
                transaction.order = index
            }
        }
        TransactionViewModel.shared.save()
    }
}

@MainActor
struct DropViewDelegate: DropDelegate {
    var grid: Grid
    var gridData: GridViewModel

    func performDrop(info _: DropInfo) -> Bool {
        gridData.updateIndices()
        gridData.currentGrid = nil
        gridData.dragging = false
        return true
    }

    func dropEntered(info _: DropInfo) {
        gridData.dragging = true

        if let unwrapped = gridData.currentGrid {
            if unwrapped.transaction == nil {
                return
            }
        }

        let fromIndex = gridData.gridItems.firstIndex { grid -> Bool in
            grid.id == gridData.currentGrid?.id
        } ?? 0

        let toIndex = gridData.gridItems.firstIndex { grid -> Bool in
            grid.id == self.grid.id
        } ?? 0

        if fromIndex != toIndex {
            withAnimation(.easeIn(duration: 0.2)) {
                let fromGrid = gridData.gridItems[fromIndex]
                gridData.gridItems[fromIndex] = gridData.gridItems[toIndex]
                gridData.gridItems[toIndex] = fromGrid
            }
        }
    }

    func dropUpdated(info _: DropInfo) -> DropProposal? {
        return DropProposal(operation: .move)
    }
}
