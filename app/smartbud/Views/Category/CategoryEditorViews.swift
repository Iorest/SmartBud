//
//  CategoryEditorViews.swift
//  smartbud
//
//  One editor for both creating and editing a category. The two screens used
//  to be separate 300-line types that had to be kept in sync by hand; they
//  now share this implementation and differ only in the header and in what
//  the save button does.
//

import SwiftUI
import SwiftData

// MARK: - Entry points

struct NewCategoryAlert: View {
    @Binding var income: Bool
    let bottomSpacers: Bool
    var budgetMode: Bool = false

    var body: some View {
        CategoryEditor(income: $income, editing: nil, budgetMode: budgetMode,
                       bottomSpacers: bottomSpacers)
    }
}

struct EditCategoryAlert: View {
    let toEdit: CategoryModel
    @Binding var showRootToast: Bool
    @Binding var rootToastTitle: String
    @Binding var rootToastImage: String
    @Binding var positive: Bool
    let bottomSpacers: Bool

    var body: some View {
        CategoryEditor(income: .constant(toEdit.income), editing: toEdit,
                       budgetMode: false, bottomSpacers: bottomSpacers) { title in
            rootToastTitle = title
            rootToastImage = "checkmark.circle.fill"
            positive = true
            showRootToast = true
        }
    }
}

// MARK: - Shared editor

struct CategoryEditor: View {
    /// Only meaningful when `editing` is nil; edit mode uses the model's side.
    @Binding var income: Bool
    let editing: CategoryModel?
    let budgetMode: Bool
    let bottomSpacers: Bool
    /// Called after a successful edit so the list can show its own toast.
    var onSaved: ((String) -> Void)?

    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var systemColorScheme
    @Environment(CategoryViewModel.self) var categoryVM

    @Namespace var animation

    var expenseCategories: [CategoryModel] { categoryVM.expenseCategories }
    @State private var availableColours: [String] = Color.colorArray

    @State private var newName = ""
    @State private var newEmoji = ""
    @State private var showingColourPicker = false
    @State private var selectedColour: String = "#FFFFFF"

    @FocusState var focusedField: FocusedField?

    enum FocusedField: Hashable {
        case emoji, name
    }

    @State var outcome = CategoryError.none
    @State var showToast = false
    @State var toastTitle = ""
    @State var toastImage = ""
    @State var positive = false

    @State var showNativePicker: Bool = false
    @State var customSelectedColor = Color.white

    @State private var toDelete: CategoryModel?
    @State private var deleted = false

    @State private var errorHaptic: Int = 0
    @State private var successHaptic: Int = 0

    private var resolvedIncome: Bool { editing?.income ?? income }

    var body: some View {
        VStack {
            VStack {
                VStack {
                    if showToast {
                        SBToast(title: toastTitle, systemImage: toastImage, positive: positive)
                            .transition(AnyTransition.opacity.combined(with: .move(edge: .top)))
                    } else if let editing {
                        Text(LocalizedStringKey(editing.income ? "Income" : "Expense"))
                            .font(.body.weight(.semibold))
                    } else {
                        if expenseCategories.count == 24 {
                            Text(String.appLocalized("Income Category"))
                                .font(.body.weight(.semibold))

                                .padding(.top, 4)
                        } else if budgetMode {
                            Text(String.appLocalized("Expense Category"))
                                .font(.body.weight(.semibold))

                                .padding(.top, 4)
                        } else {
                            HStack(spacing: 0) {
                                Button {
                                    DispatchQueue.main.async {
                                        withAnimation(.easeIn(duration: 0.15)) {
                                            income = false
                                        }
                                    }
                                } label: {
                                    Text(String.appLocalized("Expense"))
                                        .font(.callout.weight(.semibold))

                                        .foregroundStyle(income == false ? Color.PrimaryText : Color.SubtitleText)
                                        .padding(5)
                                        .padding(.horizontal, 7)
                                        .background {
                                            if income == false {
                                                Capsule()
                                                    .fill(Color.SecondaryBackground)
                                                    .matchedGeometryEffect(id: "TAB1", in: animation)
                                            }
                                        }
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)

                                Button {
                                    DispatchQueue.main.async {
                                        withAnimation(.easeIn(duration: 0.15)) {
                                            income = true
                                        }
                                    }
                                } label: {
                                    Text(String.appLocalized("Income"))
                                        .font(.callout.weight(.semibold))

                                        .foregroundStyle(income == true ? Color.PrimaryText : Color.SubtitleText)
                                        .padding(5)
                                        .padding(.horizontal, 7)
                                        .background {
                                            if income == true {
                                                Capsule()
                                                    .fill(Color.SecondaryBackground)
                                                    .matchedGeometryEffect(id: "TAB1", in: animation)
                                            }
                                        }
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(3)
                            .background(Capsule().fill(Color.PrimaryBackground).shadow(color: systemColorScheme == .light ? Color.Outline : Color.clear, radius: 6))
                            .overlay(Capsule().stroke(systemColorScheme == .light ? Color.clear : Color.Outline.opacity(0.4), lineWidth: 1.3))
                        }
                    }
                }
                .frame(height: 30)
                .frame(maxWidth: .infinity)
                .overlay(alignment: .leading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.callout.weight(.semibold))

                            .foregroundStyle(Color.SubtitleText)
                            .padding(7)
                            .background(Color.SecondaryBackground, in: Circle())
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                }
                .overlay(alignment: .trailing) {
                    if editing != nil {
                        Button {
                            toDelete = editing
                        } label: {
                            Image(systemName: "trash.fill")
                                .font(.callout.weight(.semibold))
                                .foregroundStyle(Color.AlertRed)
                                .padding(7)
                                .background(Color.AlertRed.opacity(0.23), in: Circle())
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        .accessibilityLabel(String.appLocalized("Delete"))
                    }
                }

                Spacer()

                ZStack {
                    EmojiTextField(text: $newEmoji)
                        .focused($focusedField, equals: .emoji)
                        .onChange(of: newEmoji) { _, new in
                            if String(new.onlyEmoji().suffix(1)) != new.onlyEmoji().prefix(1) {
                                newEmoji = String(new.onlyEmoji().suffix(1))
                            } else {
                                newEmoji = String(new.onlyEmoji().prefix(1))
                            }
                        }
                        .font(.system(size: 160))
                        .padding(8)
                        .frame(width: 80, height: 80, alignment: .center)
                        .background {
                            RoundedRectangle(cornerRadius: SBRadius.card, style: .continuous)
                                .strokeBorder((focusedField == .emoji && !showingColourPicker) ? Color.SubtitleText : Color.clear, lineWidth: 2.2)
                                .background(RoundedRectangle(cornerRadius: SBRadius.card, style: .continuous).fill(Color.SecondaryBackground))
                        }

                    if newEmoji == "" {
                        Image("emoji-happy")
                            .resizable()
                            .foregroundStyle(Color.PrimaryText)
                            .frame(width: 35, height: 35, alignment: .center)
                            .allowsHitTesting(false)
                    }
                }

                Spacer()

                HStack {
                    if !resolvedIncome {
                        Button {
                            showingColourPicker = true
                        } label: {
                            RoundedRectangle(cornerRadius: SBRadius.chip, style: .continuous)
                                .fill(Color(hex: selectedColour))
                                .padding(8)
                                .background(Color.SecondaryBackground, in: RoundedRectangle(cornerRadius: SBRadius.card, style: .continuous))
                                .frame(width: 50, height: 50)
                                .overlay {
                                    if showingColourPicker {
                                        RoundedRectangle(cornerRadius: SBRadius.card, style: .continuous)
                                            .stroke(Color.SubtitleText, lineWidth: 2.2)
                                    }
                                }
                        }
                        .popover(isPresented: $showingColourPicker) {
                            ColourPickerView(selectedColor: $selectedColour, showMenu: $showingColourPicker, showNativePicker: $showNativePicker, expenseCategories: expenseCategories, toEdit: editing)
                        }
                    }
                    NormalTextField(text: $newName, placeholder: String.appLocalized("Category Name"), action: verification)
                        .focused($focusedField, equals: .name)
                        .padding(.horizontal, 15)
                        .padding(.vertical, 5)
                        .foregroundStyle(Color.PrimaryText)

                        .frame(height: 50)
                        .background {
                            RoundedRectangle(cornerRadius: SBRadius.card, style: .continuous)
                                .strokeBorder((focusedField == .name && !showingColourPicker) ? Color.SubtitleText : Color.clear, lineWidth: 2.2)
                                .background(RoundedRectangle(cornerRadius: SBRadius.card, style: .continuous).fill(Color.SecondaryBackground))
                        }
                    //
                    Button {
                        verification()
                    } label: {
                        Image(systemName: editing == nil ? "plus" : "checkmark")
                            .foregroundStyle(Color.LightIcon)
                            .font(.title3.weight(.semibold))

                            .frame(width: 50, height: 50)
                            .background(Color.DarkBackground, in: RoundedRectangle(cornerRadius: SBRadius.card, style: .continuous))
                    }
                }
            }
            .padding(13)
            .frame(maxHeight: bottomSpacers ? 350 : .infinity)
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .background(.clear)
        .animation(.easeOut(duration: 0.2), value: showToast)
        .onChange(of: expenseCategories.count) { _, _ in
            if expenseCategories.count == 24 {
                dismiss()
            }
        }
        .sbToastDismissal($showToast)
        .onChange(of: customSelectedColor) { _, _ in
            selectedColour = customSelectedColor.toHex() ?? "#FFFFFF"
        }
        .colorPickerSheet(isPresented: $showNativePicker, selection: $customSelectedColor, supportsAlpha: false, title: "")
        .fullScreenPresentation(item: $toDelete, onDismiss: {
            toDelete = nil
        }) { category in
            DeleteCategoryAlert(toDelete: category, deleted: $deleted)
        }
        .onAppear(perform: seedState)
        .onChange(of: deleted) { _, _ in dismiss() }
        .modifier(ErrorSuccessHaptics(error: errorHaptic, success: successHaptic))
    }

    private func seedState() {
        if let editing {
            newName = editing.wrappedName
            newEmoji = editing.wrappedEmoji
            selectedColour = editing.wrappedColour
            return
        }
        if expenseCategories.count == 24 {
            income = true
        }
        if !income {
            availableColours = Color.colorArray
            expenseCategories.forEach { category in
                availableColours.removeAll { $0 == category.wrappedColour }
            }
            selectedColour = availableColours.first ?? "#FFFFFF"
        }
    }

    func verification() {
        let results = editing.map {
            categoryVM.validateEdit(name: newName, emoji: newEmoji, exclude: $0)
        } ?? categoryVM.validate(name: newName, emoji: newEmoji, income: income)

        outcome = results.error

        if outcome != .none {
            errorHaptic &+= 1

            switch outcome {
            case .incomplete:
                toastTitle = String.appLocalized("Incomplete Entry")
                toastImage = "questionmark.app"
            case .missingEmoji:
                toastTitle = String.appLocalized("Missing Emoji")
                toastImage = "person.fill"
                focusedField = .emoji
            case .missingName:
                toastTitle = String.appLocalized("Missing Name")
                toastImage = "character.cursor.ibeam"
                focusedField = .name
            case .duplicate:
                toastTitle = String.appLocalized("Duplicate Found")
                toastImage = "externaldrive"
            case .duplicateEmoji:
                toastTitle = String.appLocalized("Duplicate Emoji")
                toastImage = "person.fill"
                focusedField = .emoji
            case .duplicateName:
                toastTitle = String.appLocalized("Duplicate Name")
                toastImage = "character.cursor.ibeam"
                focusedField = .name
            default:
                return
            }

            positive = false
            showToast = true
            return
        }

        successHaptic &+= 1
        let trimmedName = newName.trimmingCharacters(in: .whitespaces).capitalized

        if let editing {
            let colour = editing.income ? editing.colour : selectedColour
            categoryVM.update(editing, name: trimmedName, emoji: newEmoji, colour: colour)
            onSaved?(String.appFormatted("Edited %@", newName))

            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(150))
                dismiss()
            }
            return
        }

        toastTitle = String.appFormatted("Added %@", newName)
        _ = categoryVM.create(
            name: trimmedName,
            emoji: newEmoji,
            colour: income ? "IncomeGreen" : selectedColour,
            income: income,
            order: results.order
        )
        newName = ""
        newEmoji = ""

        if budgetMode {
            dismiss()
        } else {
            if !income {
                seedState()
            }
            focusedField = .emoji
            toastImage = "checkmark.circle.fill"
            positive = true
            showToast = true
        }
    }
}
