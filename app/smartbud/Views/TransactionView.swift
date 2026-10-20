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

    @AppStorage("topEdge", store: .appGroup) var topEdge:
    Double = 20

    @State var note = ""
    @State var category: CategoryModel?
    @State var date = Date.now
    @State var showSmartEntry = false
    /// Non-empty draft → Cancel asks before discarding (HIG error tolerance).
    @State var showDiscardConfirmation = false

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
        }
        return padVM.price > 0 || !note.isEmpty || category != nil
    }
    @State var repeatType = 0
    @State var repeatCoefficient = 1
    @State var income = false

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
    @State var errorHaptic = 0
    @State private var isSubmitting = false
    @State var successHaptic = 0
    @State var lightHaptic = 0

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

    @AppStorage("colourScheme", store: .appGroup)
    var colourScheme: Int = 0

    @Environment(\.colorScheme) var systemColorScheme

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

    @State var padVM = NumberPadViewModel(numberEntryType: 1, hapticType: 1)
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
    func applyParsed(_ parsed: ParsedExpense) {
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

        if let validationError = TransactionValidation.error(
            amount: amount, hasCategory: category != nil
        ) {
            toastImage = validationError.systemImage
            toastTitle = String.appLocalized(validationError.toastTitleKey)
            showToast = true
            if validationError.highlightsFields {
                toggleFieldColors()
            }

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

            transactionVM.update(editedTransaction, with: TransactionEdit(
                note: finalNote,
                category: category,
                income: income,
                amount: amount,
                date: date,
                repeatType: repeatType,
                repeatCoefficient: repeatCoefficient
            ))

            dismiss()

            return
        }

        transactionVM.create(TransactionEdit(
            note: note.trimmingCharacters(in: .whitespacesAndNewlines) == ""
                ? (category?.wrappedName ?? "") : note.trimmingCharacters(in: .whitespaces),
            category: category,
            income: income,
            amount: amount,
            date: date,
            repeatType: repeatType,
            repeatCoefficient: repeatCoefficient
        ))

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
