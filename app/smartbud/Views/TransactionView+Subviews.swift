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
        .sbToastDismissal($showToast, after: toastSticks ? nil : .seconds(2))
        // A sticky refusal clears on the first edit, so the picker it
        // replaced comes back without hunting for a close button.
        .onChange(of: padVM.price) { _, _ in clearStickyToast() }
        .onChange(of: date) { _, _ in clearStickyToast() }
        .onChange(of: income) { _, newValue in
            clearStickyToast()
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
            availableTags = TagStore.all(
                in: DataRepository.shared.container.mainContext,
                bookID: BookState.shared.currentID)
            smartHistory = transactionVM.parseHistory()
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
                    // A restored backup carries references but not bytes.
                    // Fetch any missing CKAsset when the row is opened.
                    if !transaction.attachments.isEmpty {
                        let refs = transaction.attachments
                        let id = transaction.id
                        Task { await ReceiptAttachmentSync.downloadMissing(refs, transactionID: id) }
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
                incomeCategories: categoryVM.incomeCategories,
                history: smartHistory
            ) { parsed in
                applyParsed(parsed)
            }
        }
        .sheet(isPresented: $showTagPicker) { tagPickerSheet }
        .sheet(isPresented: $showReceiptViewer) { receiptViewerSheet }
        .photosPicker(
            isPresented: $showReceiptPicker,
            selection: $receiptItems,
            maxSelectionCount: ReceiptAttachmentPolicy.maxCount,
            matching: .images
        )
        .onChange(of: receiptItems) { _, items in
            receiptsChanged = true
            Task {
                var loaded: [Data] = []
                for item in items.prefix(ReceiptAttachmentPolicy.maxCount) {
                    if let data = try? await item.loadTransferable(type: Data.self) {
                        loaded.append(data)
                    }
                }
                receiptData = loaded
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

// MARK: - Smart entry

extension TransactionView {
    /// Fills the form from a smart-entry parse result. Nothing is saved here —
    /// the user still submits the form themselves.
    func applyParsed(_ parsed: ParsedExpense) {
        income = parsed.isIncome
        // Parsed amounts come from OCR/text and never went through the pad's
        // own cap, so a stray long number could enter a 9-digit amount.
        let cap = Decimal(Money.maxAmount)
        padVM.price = Money.double(parsed.amount > cap ? cap : parsed.amount)
        if note.isEmpty, let merchant = parsed.merchant {
            note = merchant
        }
        let pool = parsed.isIncome ? categoryVM.incomeCategories : categoryVM.expenseCategories
        if let name = parsed.categoryName,
           let match = pool.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) {
            category = match
        } else if let match = ExpenseTextParser.resolveCategory(parsed.categoryHint, from: pool) {
            category = match
        }
    }
}

extension TransactionView {
    /// Parses the discount alert's text into a non-negative amount.
    func applyDiscount() {
        let cleaned = discountInput
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: ",", with: ".")
        let value = Double(cleaned) ?? 0
        discount = value.isFinite ? max(0, min(value, Money.maxAmount)) : 0
        discountInput = ""
    }
}

// MARK: - Label picker

extension TransactionView {
    /// Multi-select labels plus inline CRUD. Deleting a label strips its id
    /// from every row in the same save, so no transaction points at a ghost.
    var tagPickerSheet: some View {
        NavigationStack {
            List {
                Section(String.appLocalized("Labels")) {
                    ForEach(availableTags) { tag in
                        Button {
                            if selectedTagIDs.contains(tag.id) {
                                selectedTagIDs.remove(tag.id)
                            } else {
                                selectedTagIDs.insert(tag.id)
                            }
                        } label: {
                            HStack {
                                Image(systemName: selectedTagIDs.contains(tag.id)
                                      ? "checkmark.circle.fill" : "circle")
                                Text(tag.name)
                                Spacer()
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier(AccessibilityID.entryTagToggle)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) { deleteTag(tag) } label: {
                                Label(String.appLocalized("Delete"), systemImage: "trash")
                            }
                        }
                    }
                }
                Section(String.appLocalized("New Label")) {
                    HStack {
                        TextField(String.appLocalized("Label name"), text: $newTagName)
                        Button(String.appLocalized("Add")) { addTag() }
                            .disabled(newTagName.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
            .navigationTitle(String.appLocalized("Labels"))
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String.appLocalized("Done")) { showTagPicker = false }
                }
            }
        }
    }

    private func addTag() {
        let name = newTagName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        let tag = TagModel(name: name, color: Color.blue.toHex() ?? "#5E9EFF")
        availableTags = TagStore.upsert(
            tag, in: DataRepository.shared.container.mainContext,
            bookID: BookState.shared.currentID)
        selectedTagIDs.insert(tag.id)
        newTagName = ""
        _ = DataRepository.shared.save()
    }

    private func deleteTag(_ tag: TagModel) {
        let context = DataRepository.shared.container.mainContext
        _ = TagStore.remove(
            id: tag.id, in: context, bookID: BookState.shared.currentID)
        for row in DataRepository.shared.fetch(TransactionModel.self)
            where row.tagIDs.contains(tag.id) {
            row.tagIDs.removeAll { $0 == tag.id }
        }
        selectedTagIDs.remove(tag.id)
        availableTags = TagStore.all(in: context, bookID: BookState.shared.currentID)
        _ = DataRepository.shared.save()
    }
}

// MARK: - Receipt viewer

extension TransactionView {
    /// Bytes for the viewer: freshly picked photos, or files already on disk
    /// for an edited row. Missing files are skipped, not shown as blank tiles.
    private var receiptPreviewData: [Data] {
        if receiptsChanged { return receiptData }
        guard let transaction = toEdit else { return [] }
        return transaction.attachments.compactMap { ref in
            guard let url = ReceiptAttachmentStore.fileURL(
                for: ref, transactionID: transaction.id) else { return nil }
            return try? Data(contentsOf: url)
        }
    }

    private func receiptImage(_ data: Data) -> Image? {
        guard let image = UIImage(data: data) else { return nil }
        #if os(macOS)
        return Image(nsImage: image)
        #else
        return Image(uiImage: image)
        #endif
    }

    var receiptViewerSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(Array(receiptPreviewData.enumerated()), id: \.offset) { _, data in
                        if let image = receiptImage(data) {
                            image
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: .infinity)
                                .clipShape(RoundedRectangle(cornerRadius: SBRadius.card))
                        }
                    }
                }
                .padding()
            }
            .navigationTitle(String.appLocalized("View Receipts"))
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String.appLocalized("Done")) { showReceiptViewer = false }
                }
            }
        }
    }
}
