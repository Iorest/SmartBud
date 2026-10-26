//
//  TemplatesView.swift
//  smartbud
//
//  Entry point for saved transactions. Templates had a model and CRUD in
//  `TransactionViewModel` but no way to reach them; this screen is that way.
//

import SwiftData
import SwiftUI

struct TemplatesView: View {
    @Environment(TransactionViewModel.self) private var transactionVM
    @Environment(CategoryViewModel.self) private var categoryVM
    @Query(sort: [SortDescriptor(\TemplateTransactionModel.order)]) private var templates: [TemplateTransactionModel]

    @State private var showEditor = false
    @State private var editingTemplate: TemplateTransactionModel?
    @State private var pendingDelete: TemplateTransactionModel?
    @State private var loggedTemplateID: UUID?
    @State private var showMissingCategory = false
    @State private var saveFailed = false

    var body: some View {
        List {
            if templates.isEmpty {
                ContentUnavailableView {
                    Label(String.appLocalized("No templates yet"), systemImage: "square.on.square")
                } description: {
                    Text(String.appLocalized("Save a transaction you record often. "
                         + "Tap a template to log it instantly."))
                } actions: {
                    Button(String.appLocalized("New Template")) { showEditor = true }
                        .buttonStyle(.borderedProminent)
                }
                .listRowSeparator(.hidden)
            } else {
                Section {
                    ForEach(templates) { template in
                        templateRow(template)
                    }
                    .onMove(perform: move)
                    .onDelete(perform: requestDelete)
                } footer: {
                    Text(String.appLocalized("Tap a template to log it instantly. Swipe a row to edit or delete it."))
                }
            }
        }
        .alert(String.appLocalized("Missing Category"), isPresented: $showMissingCategory) {
            Button(String.appLocalized("alert.ok"), role: .cancel) {}
        } message: {
            Text(String.appLocalized("Select a category"))
        }
        .alert(String.appLocalized("无法保存更改，请稍后重试。"), isPresented: $saveFailed) {
            Button(String.appLocalized("alert.ok"), role: .cancel) {}
        }
        .navigationTitle(String.appLocalized("Templates"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showEditor = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel(Text(String.appLocalized("New Template")))
            }
            #if os(iOS)
            if !templates.isEmpty {
                ToolbarItem(placement: .topBarLeading) {
                    EditButton()
                }
            }
            #endif
        }
        .sheet(isPresented: $showEditor) {
            TemplateEditorView(template: nil, nextOrder: nextOrder)
        }
        .sheet(item: $editingTemplate) { template in
            TemplateEditorView(template: template, nextOrder: template.order)
        }
        .confirmationDialog(
            String.appLocalized("Delete Template?"),
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button(String.appLocalized("Delete"), role: .destructive) {
                if let pendingDelete { transactionVM.deleteTemplate(pendingDelete) }
                pendingDelete = nil
            }
            Button(String.appLocalized("Cancel"), role: .cancel) { pendingDelete = nil }
        } message: {
            Text(String.appLocalized("The template is removed. Transactions already logged with it are not affected."))
        }
    }

    private func templateRowLabel(_ template: TemplateTransactionModel) -> some View {
        HStack(spacing: SBSpace.small) {
                EmojiLogView(
                    emoji: template.wrappedEmoji,
                    colour: template.wrappedColour,
                    future: false
                )
                .fixedSize(horizontal: true, vertical: true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(template.wrappedNote.isEmpty
                         ? (template.category?.wrappedName ?? String.appLocalized("Template"))
                         : template.wrappedNote)
                        .font(.body)
                        .foregroundStyle(Color.PrimaryText)
                        .lineLimit(1)

                    if let category = template.category, !template.wrappedNote.isEmpty {
                        Text(category.wrappedName)
                            .font(.subheadline)
                            .foregroundStyle(Color.SubtitleText)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: SBSpace.extraSmall)

                VStack(alignment: .trailing, spacing: 2) {
                    Text(amountText(template))
                        .font(.body.monospacedDigit())
                        .foregroundStyle(template.income ? Color.IncomeGreen : Color.PrimaryText)
                        .lineLimit(1)

                    if loggedTemplateID == template.id {
                        Label(String.appLocalized("Logged"), systemImage: "checkmark")
                            .font(.caption)
                            .foregroundStyle(Color.SubtitleText)
                    }
                }
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
    }

    private var nextOrder: Int {
        (templates.map(\.order).max() ?? -1) + 1
    }

    private func templateRow(_ template: TemplateTransactionModel) -> some View {
        Button {
            switch transactionVM.applyTemplate(template.order) {
            case .success:
                break
            case .missingCategory:
                showMissingCategory = true
                return
            case .saveFailed:
                saveFailed = true
                return
            }
            withAnimation { loggedTemplateID = template.id }
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(1.5))
                withAnimation {
                    if loggedTemplateID == template.id { loggedTemplateID = nil }
                }
            }
        } label: {
            templateRowLabel(template)
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                pendingDelete = template
            } label: {
                Label(String.appLocalized("Delete"), systemImage: "trash")
            }

            Button {
                editingTemplate = template
            } label: {
                Label(String.appLocalized("Edit"), systemImage: "pencil")
            }
            .tint(.accentColor)
        }
    }

    private func amountText(_ template: TemplateTransactionModel) -> String {
        LogGrouping.currency(
            template.amount,
            code: AppBaseCurrency.code,
            showCents: UserDefaults.appGroup.object(forKey: "showCents") as? Bool ?? true,
            signed: false,
            income: template.income
        )
    }

    private func move(from source: IndexSet, to destination: Int) {
        var ordered = templates
        ordered.move(fromOffsets: source, toOffset: destination)
        transactionVM.reorderTemplates(ordered)
    }

    private func requestDelete(at offsets: IndexSet) {
        guard let index = offsets.first else { return }
        pendingDelete = templates[index]
    }
}

// MARK: - Editor

struct TemplateEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(TransactionViewModel.self) private var transactionVM
    @Environment(CategoryViewModel.self) private var categoryVM

    let template: TemplateTransactionModel?
    let nextOrder: Int

    @State private var note = ""
    @State private var amountText = ""
    @State private var income = false
    @State private var category: CategoryModel?
    @State private var repeatType = 0

    private var categories: [CategoryModel] {
        income ? categoryVM.incomeCategories : categoryVM.expenseCategories
    }

    private var amount: Double? {
        Double(amountText.replacingOccurrences(of: ",", with: "."))
    }

    private var canSave: Bool {
        category != nil && (amount ?? 0) > 0
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(String.appLocalized("Note"), text: $note)

                    HStack {
                        Text(String.appLocalized("Amount"))
                        Spacer()
                        TextField("0", text: $amountText)
                            #if os(iOS)
                            .keyboardType(.decimalPad)
                            #endif
                            .multilineTextAlignment(.trailing)
                            .monospacedDigit()
                    }

                    Picker(String.appLocalized("Type"), selection: $income) {
                        Text(String.appLocalized("Expense")).tag(false)
                        Text(String.appLocalized("Income")).tag(true)
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    Picker(String.appLocalized("Category"), selection: $category) {
                        Text(String.appLocalized("Select")).tag(CategoryModel?.none)
                        ForEach(categories) { item in
                            Text("\(item.wrappedEmoji) \(item.wrappedName)")
                                .tag(Optional(item))
                        }
                    }

                    Picker(String.appLocalized("Repeat"), selection: $repeatType) {
                        Text(String.appLocalized("None")).tag(0)
                        Text(String.appLocalized("Daily")).tag(1)
                        Text(String.appLocalized("Weekly")).tag(2)
                        Text(String.appLocalized("Monthly")).tag(3)
                    }
                }
            }
            .navigationTitle(String.appLocalized(template == nil ? "New Template" : "Edit"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String.appLocalized("Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String.appLocalized("Save")) { save() }
                        .disabled(!canSave)
                }
            }
            .onAppear(perform: load)
            .onChange(of: income) { _, _ in
                // The category list flips with the type; keep a valid pick.
                if let category, category.income != income {
                    self.category = nil
                }
            }
        }
    }

    private func load() {
        guard let template else {
            category = categories.first
            return
        }
        note = template.wrappedNote
        amountText = String(format: "%.2f", template.amount)
        income = template.income
        category = template.category
        repeatType = template.recurringType
    }

    private func save() {
        guard let category, let amount else { return }
        transactionVM.createOrUpdateTemplate(TemplateDefinition(
            order: nextOrder,
            note: note,
            category: category,
            income: income,
            amount: amount,
            repeatType: repeatType,
            repeatCoefficient: repeatType == 0 ? 0 : 1
        ))
        dismiss()
    }
}
