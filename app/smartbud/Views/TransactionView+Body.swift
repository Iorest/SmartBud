//
//  TransactionView+Body.swift
//  smartbud
//
import Foundation
import SwiftUI

extension TransactionView {

    func formattedAmount(_ amount: Double) -> String {
        "\(currencySymbol)\(Int(round(amount)))"
    }

    func chipColor(_ hex: String) -> Color {
        Color(hex: hex)
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

            TransactionRepeatButton(
                repeatType: $repeatType,
                repeatCoefficient: $repeatCoefficient,
                showPicker: $showPicker
            )
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
                SBToast(title: toastTitle, systemImage: toastImage)
                    .transition(AnyTransition.opacity.combined(with: .move(edge: .top)))
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
                NumberPadTextView(viewModel: padVM, currencySymbol: currencySymbol)
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
                    ForEach(suggestedTransactions, id: \.id) { transaction in
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
                viewModel: padVM,
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

    var dateButton: some View {
        TransactionDateRow(date: date, animateIcon: animateIcon) {
            hideKeyboard()
            showingDatePicker = true
        }
    }

    private var categoryButtonArea: some View {
        TransactionCategoryRow(
            category: category,
            hasCategories: income
                ? !categoryVM.incomeCategories.isEmpty
                : !categoryVM.expenseCategories.isEmpty,
            isPickerOpen: $showCategoryPicker,
            textColor: categoryButtonTextColor,
            backgroundColor: categoryButtonBackgroundColor,
            outlineColor: categoryButtonOutlineColor,
            shake: shake
        )
    }

    @ViewBuilder
    var expenseToggleButton: some View {
        Button {
            withAnimation(.easeIn(duration: 0.15)) {
                income = false
                swipingOffset = 0
            }
        } label: {
            Text(String.appLocalized("Expense"))
                .font(.body.weight(.semibold))
                .lineLimit(1)
                .foregroundStyle(income == false ? Color.PrimaryText : Color.SubtitleText)
                .padding(6)
                .frame(width: capsuleWidth)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(income == false ? .isSelected : [])
    }

    @ViewBuilder
    var incomeToggleButton: some View {
        Button {
            withAnimation(.easeIn(duration: 0.15)) {
                income = true
                swipingOffset = capsuleWidth
            }
        } label: {
            Text(String.appLocalized("transaction-view-income-picker"))
                .font(.body.weight(.semibold))
                .lineLimit(1)
                .foregroundStyle(income == true ? Color.PrimaryText : Color.SubtitleText)
                .padding(6)
                .frame(width: capsuleWidth)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(income == true ? .isSelected : [])
    }

    var dateString: String {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale.appLocale
        dateFormatter.dateFormat = "d MMM yyyy"
        return dateFormatter.string(from: date)
    }

}
