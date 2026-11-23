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
            .accessibilityHint(Text(String.appLocalized("Discard this edit")))
            .accessibilityIdentifier(AccessibilityID.entryCancel)

            Spacer()

            if toEdit != nil {
                Button {
                    toDelete = toEdit
                    deleteMode = true

                } label: {
                    deleteButtonIcon
                }
                .accessibilityLabel(String.appLocalized("delete transaction"))
                .accessibilityHint(Text(String.appLocalized("Permanently delete this transaction")))
            }

            TransactionRepeatButton(
                repeatType: $repeatType,
                repeatCoefficient: $repeatCoefficient,
                showPicker: $showPicker
            )
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    var toastOrIncomeExpensePicker: some View {
        VStack {
            if showToast {
                SBToast(title: toastTitle, systemImage: toastImage)
                    .appTransition(AnyTransition.opacity.combined(with: .move(edge: .top)))
                    // Sticky refusals stay until edited; tapping the message
                    // is the explicit "I read it" for users who want the
                    // income/expense picker back first.
                    .onTapGesture { clearStickyToast() }
            } else {
                Picker(String.appLocalized("Type"), selection: $income) {
                    Text(String.appLocalized("Expense")).tag(false)
                    Text(String.appLocalized("Income")).tag(true)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(maxWidth: SBControlWidth.segment)
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
        .accessibilityHint(Text(String.appLocalized("Generate a transaction from text")))
        .accessibilityIdentifier(AccessibilityID.entrySmartEntry)
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
            // The extras row is always there; the account chip joins it once
            // the user has an account (discount and claims work without one).
            HStack(spacing: 6) {
                if !accountVM.accounts.isEmpty {
                    TransactionAccountChip(account: account) {
                        hideKeyboard()
                        showAccountPicker = true
                    }
                    .accessibilityIdentifier(AccessibilityID.entryAccountChip)
                    Spacer(minLength: 4)
                }

                entryOptionChips
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 6)

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
            .appTransition(AnyTransition.move(edge: .trailing).combined(with: .opacity))
        } else if !textFieldFocused {
            // The system keyboard owns the bottom while the note is typed.
            NumberPad(
                viewModel: padVM,
                showingNotePicker: showingNotePicker,
                category: category,
                submit: { submit() },
                submitAndContinue: {
                    // One-off "stay open" for users who keep the setting off.
                    keepEntering = true
                    submit()
                }
            )
            .appTransition(AnyTransition.move(edge: .leading).combined(with: .opacity))
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
        .accessibilityIdentifier(AccessibilityID.entryDateButton)
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

    var dateString: String {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale.appLocale
        dateFormatter.dateFormat = "d MMM yyyy"
        return dateFormatter.string(from: date)
    }

    // MARK: - Discount and reimbursement chips

    /// Two compact chips that sit opposite the account chip. Both are
    /// optional extras, so they stay out of the way until used.
    @ViewBuilder
    var entryOptionChips: some View {
        HStack(spacing: 6) {
            // A discount only means something on an expense.
            if !income {
                TransactionOptionChip(
                    systemImage: "tag",
                    title: discount > 0
                        ? Money.format(discount,
                                       currencyCode: account?.resolvedCurrencyCode ?? currency,
                                       showsCents: false, locale: .appLocale)
                        : String.appLocalized("Discount"),
                    isOn: discount > 0
                ) {
                    hideKeyboard()
                    discountInput = discount > 0 ? String(format: "%.2f", discount) : ""
                    showDiscountEditor = true
                }
                .accessibilityIdentifier(AccessibilityID.entryDiscountChip)
            }

            if !income {
                TransactionOptionChip(
                    systemImage: reimbursable ? "checkmark.circle.fill" : "arrow.uturn.backward.circle",
                    title: String.appLocalized("Claim"),
                    isOn: reimbursable
                ) {
                    withAnimation(.easeOut(duration: 0.15)) { reimbursable.toggle() }
                    lightHaptic &+= 1
                }
                .accessibilityIdentifier(AccessibilityID.entryClaimChip)
            }
        }
    }

}

// MARK: - Draft detection

extension TransactionView {
    /// True when closing would throw away work. New entries count once any
    /// field is filled; edits count only once a field actually changed, so
    /// opening and closing an existing transaction never nags.
    var hasDraft: Bool {
        if let toEdit {
            return padVM.price != toEdit.wrappedAmount
                || note != toEdit.wrappedNote
                || category?.id != toEdit.category?.id
                || income != toEdit.income
                || date != toEdit.wrappedDate
                || discount != toEdit.discount
                || reimbursable != toEdit.reimbursable
        }
        // A category alone is not a draft: continuous-entry keeps the last
        // category selected, so requiring it made every Cancel ask "discard?"
        // even with an empty amount and note.
        return padVM.price > 0
            || !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || discount > 0
            || reimbursable
    }
}
