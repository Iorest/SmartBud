//
//  TransactionView+Subviews.swift
//  smartbud
//
import Foundation
import SwiftUI

extension TransactionView {

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
        // Bleed to the bottom only: the number pad should reach the home
        // indicator. Ignoring the top edge as well pushed the header (the
        // Cancel button and the expense/income picker) under the status bar,
        // where the system swallows the touches and Cancel stopped working.
        // The keyboard safe area stays active so SwiftUI lifts the form above
        // the system keyboard on its own.
        .frame(maxHeight: .infinity)
        .ignoresSafeArea(.container, edges: .bottom)
        #endif
        // An alert rather than a confirmation dialog: this screen is a
        // full-screen cover with a fixed, keyboard-avoiding frame, where an
        // action sheet is clipped by the keypad.
        .alert(
            String.appLocalized((toDelete?.income ?? income) ? "Delete Income?" : "Delete Expense?"),
            isPresented: $deleteMode
        ) {
            Button(String.appLocalized("Delete"), role: .destructive) {
                withAnimation {
                    if let itemToDelete = toDelete {
                        transactionVM.delete(itemToDelete)
                    }
                }
                toDelete = nil
                dismiss()
            }
            Button(String.appLocalized("Cancel"), role: .cancel) { toDelete = nil }
        } message: {
            Text(String.appLocalized("This action cannot be undone."))
        }
        // Control-dense surface (keypad + fixed rows). Let text grow to the
        // first accessibility size, then stop: beyond that the keypad and the
        // date/category row cannot fit on a phone. Documented exception to
        // unlimited scaling, same approach as Apple's Calculator.
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        .sbToastDismissal($showToast)
        .onChange(of: income) { _, newValue in
            lightHaptic &+= 1
            // Only drop a category that belongs to the other side; clearing
            // unconditionally wiped the category when editing an income
            // transaction (onAppear sets `income` after `category`).
            if let category, category.income != newValue {
                self.category = nil
            }
            // Income can be neither claimed back nor discounted.
            if newValue {
                reimbursable = false
                discount = 0
            }
        }
        .onChange(of: numberEntryType) { _, new in
            padVM.numberEntryType = new
        }
        .onAppear {
            categoryVM.load()
            accountVM.load()
            if account == nil {
                account = accountVM.defaultAccount(lastUsedID: lastAccountID)
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
        .alert(String.appLocalized("Discount"), isPresented: $showDiscountEditor) {
            TextField("0", text: $discountInput)
                #if os(iOS)
                .keyboardType(.decimalPad)
                #endif
            Button(String.appLocalized("Cancel"), role: .cancel) {}
            Button(String.appLocalized("Done")) { applyDiscount() }
        } message: {
            Text(String.appLocalized(
                "How much came off the listed price. The number pad already shows what you paid."))
        }
        .sheet(isPresented: $showAccountPicker) {
            AccountPickerSheet(selection: $account)
                .environment(accountVM)
        }
        .sheet(isPresented: $showPicker) {
                CustomRecurringView(
                    repeatType: $repeatType, repeatCoefficient: $repeatCoefficient, showPicker: $showPicker
                )
                .presentationDetents([.medium, .large])
        }
        .sensoryFeedback(.impact(weight: .light), trigger: lightHaptic)
        .sensoryFeedback(.error, trigger: errorHaptic)
        .sensoryFeedback(.success, trigger: successHaptic)
    }
}
