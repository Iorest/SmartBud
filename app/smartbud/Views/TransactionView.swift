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
                || discount != toEdit.discount
                || reimbursable != toEdit.reimbursable
        }
        return padVM.price > 0 || !note.isEmpty || category != nil
            || discount > 0 || reimbursable
    }
    @State var repeatType = 0
    @State var repeatCoefficient = 1
    @State var income = false

    /// How much was knocked off the listed price. `amount` already holds the
    /// net total, so this only feeds the "原价" line and the export.
    @State var discount: Double = 0
    @State var showDiscountEditor = false
    @State var discountInput = ""

    /// Claims the expense back; claims are excluded from spend statistics.
    @State var reimbursable = false

    @State var showCategoryPicker = false
    @State var showCategorySheet = false

    @State var account: AccountModel?
    @State var showAccountPicker = false
    @Environment(AccountViewModel.self) var accountVM

    /// Remembers the account used most recently so repeat entries are one tap.
    @AppStorage("lastAccountID", store: .appGroup) var lastAccountID: String = ""

    @AppStorage("currency", store: .appGroup) var currency: String = Locale.current.currency?.identifier ?? "USD"
    /// The form edits an amount in the selected account's currency.
    var currencySymbol: String {
        let code = account?.resolvedCurrencyCode ?? currency
        return Locale.appCurrencySymbol(forCurrencyCode: code)
    }

    @State var showingDatePicker = false
    @State var showingCategoryView = false

    // toasts
    @State var showToast = false
    @State var toastTitle = ""
    @State var toastImage = ""

    /// Keeps the form open after saving (Settings → Number Entry, or a
    /// one-off long-press on the checkmark).
    @AppStorage("continuousEntry", store: .appGroup) private var continuousEntry = false
    @State var keepEntering = false

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

    @AppStorage("colourScheme", store: .appGroup)
    var colourScheme: Int = 0

    @State var showPicker = false
    @State var animateIcon = false

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

    @State var padVM = NumberPadViewModel(numberEntryType: 1, hapticType: 1)
    @AppStorage("numberEntryType", store: .appGroup)
    var numberEntryType: Int = 1
    @AppStorage("haptics", store: .appGroup)
    var hapticType: Int = 1

    /// `currency` is declared at the top of the struct (line ~45) and re-read
    /// here. We just need the `currencySymbol` derived from the existing
    /// `currency` value to pass into `NumberPadTextView`.

    @ViewBuilder
    var headerArea: some View {
        if usesLargeTextLayout || toEdit != nil {
            // At large sizes the Cancel/repeat/delete buttons overlap the
            // income/expense capsule on narrow phones, so give each its row.
            // The delete button only exists while editing, hence the check.
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

    func submit() {
        // A fast double tap on the checkmark used to create two rows.
        guard !isSubmitting else { return }
        isSubmitting = true

        let amount = padVM.price
        // Adjustment rows and repayment rows are defined by having no
        // category; requiring one made them uneditable.
        let categoryOptional = toEdit?.adjustment == true || toEdit?.reimbursementOf != nil
        if let validationError = TransactionValidation.error(
            amount: amount, hasCategory: category != nil,
            requiresCategory: !categoryOptional
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
            applyEdit(editedTransaction, amount: amount)
            return
        }

        transactionVM.create(TransactionEdit(
            note: note.trimmingCharacters(in: .whitespacesAndNewlines) == ""
                ? (category?.wrappedName ?? "") : note.trimmingCharacters(in: .whitespaces),
            category: category,
            account: account,
            income: income,
            amount: amount,
            date: date,
            repeatType: repeatType,
            repeatCoefficient: repeatCoefficient,
            discount: discount,
            reimbursable: reimbursable && !income
        ))

        // Reset pad state (price / decimal / haptic trigger) for the next
        // entry. The pad's submit button also clears the VM via `vm.submit()`,
        // but we clear again here in case the user taps a different commit
        // path (e.g. via the keyboard return key) before the pad re-renders.
        padVM.submit()
        finishEntry()
    }

    /// Writes an edited transaction, keeping the note in sync with the
    /// category when the user never typed one.
    private func applyEdit(_ transaction: TransactionModel, amount: Double) {
        let trimmedNote = note.trimmingCharacters(in: .whitespaces)
        let finalNote: String
        if let category {
            finalNote = trimmedNote.isEmpty ? category.wrappedName : trimmedNote
        } else {
            finalNote = trimmedNote
        }

        transactionVM.update(transaction, with: TransactionEdit(
            note: finalNote,
            category: category,
            account: account,
            income: income,
            amount: amount,
            date: date,
            repeatType: repeatType,
            repeatCoefficient: repeatCoefficient,
            discount: discount,
            reimbursable: reimbursable && !income
        ))

        dismiss()
    }

    /// Parses the discount alert's text into a non-negative amount.
    func applyDiscount() {
        let cleaned = discountInput
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: ",", with: ".")
        let value = Double(cleaned) ?? 0
        discount = value.isFinite ? max(0, min(value, Money.maxAmount)) : 0
        discountInput = ""
    }

    /// Closes the form, or keeps it open in continuous-entry mode.
    private func finishEntry() {
        if let account {
            lastAccountID = account.id.uuidString
        }

        let stayOpen = continuousEntry || keepEntering
        keepEntering = false

        guard stayOpen else {
            dismiss()
            return
        }

        // Keep category, date, income and recurrence so the next transaction
        // is a one-tap repeat, but clear what's per-entry.
        note = ""
        discount = 0
        reimbursable = false
        toastImage = "checkmark.circle.fill"
        toastTitle = String.appLocalized("Saved")
        showToast = true
        // Without this the guard at the top of `submit()` would swallow the
        // next tap; `dismiss()` used to make the reset unnecessary.
        isSubmitting = false
    }

    init(toEdit: TransactionModel? = nil) {
        if let transaction = toEdit {
            _note = State(initialValue: transaction.wrappedNote)

            if let unwrappedCategory = transaction.category {
                _category = State(initialValue: unwrappedCategory)
            }

            _income = State(initialValue: transaction.income)

            _date = State(initialValue: transaction.date ?? Date.now)
            _account = State(initialValue: transaction.account)
            _discount = State(initialValue: transaction.discount)
            _reimbursable = State(initialValue: transaction.reimbursable)
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
