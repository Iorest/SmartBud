import CoreHaptics
import Foundation
import SwiftUI
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

struct NewCategoryAlert: View {
    @Binding var income: Bool
    let budgetMode: Bool
    let bottomSpacers: Bool

    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var systemColorScheme
    @Environment(CategoryViewModel.self) var categoryVM

    @Namespace var animation

    // existing categories

    var expenseCategories: [CategoryModel] { categoryVM.expenseCategories }
    var incomeCategories: [CategoryModel] { categoryVM.incomeCategories }
    @State private var availableColours: [String] = Color.colorArray

    // state
    @State private var newName = ""
    @State private var newEmoji = ""
    @State private var showingColourPicker = false
    @State private var selectedColour: String = "#FFFFFF"

    @FocusState var focusedField: FocusedField?

    enum FocusedField: Hashable {
        case emoji, name
    }

    // toasts
    @State var outcome = CategoryError.none
    @State var showToast = false
    @State var toastTitle = ""
    @State var toastImage = ""
    @State var positive = false

    @State var showNativePicker: Bool = false
    @State var customSelectedColor = Color.white

    // haptic triggers (used to scope the modifier chain length)
    @State private var errorHaptic: Int = 0
    @State private var successHaptic: Int = 0

    var body: some View {
        VStack {
            VStack {
                VStack {
                    if showToast {
                        SBToast(title: toastTitle, systemImage: toastImage, positive: positive)
                            .transition(AnyTransition.opacity.combined(with: .move(edge: .top)))
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
                            .contentShape(Circle())
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
                    if !income {
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
                            ColourPickerView(selectedColor: $selectedColour, showMenu: $showingColourPicker, showNativePicker: $showNativePicker, expenseCategories: expenseCategories)
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
                        Image(systemName: "plus")
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
        .onAppear {
            if expenseCategories.count == 24 {
                income = true
            }

            if !income {
                expenseCategories.forEach { category in
                    if availableColours.contains(category.wrappedColour) {
                        availableColours.removeAll { $0 == category.wrappedColour }
                    }
                }

                if availableColours.isEmpty {
                    selectedColour = "#FFFFFF"
                } else {
                    selectedColour = availableColours[0]
                }
            }
        }
        .modifier(ErrorSuccessHaptics(error: errorHaptic, success: successHaptic))
    }

    func verification() {
        let results = categoryVM.validate(name: newName, emoji: newEmoji, income: income)

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

        } else {
            toastTitle = String.appFormatted("Added %@", newName)

            successHaptic &+= 1

            if income {
                _ = categoryVM.create(name: newName.trimmingCharacters(in: .whitespaces).capitalized, emoji: newEmoji, colour: "IncomeGreen", income: true, order: results.order)

                newName = ""
                newEmoji = ""
            } else {
                _ = categoryVM.create(name: newName.trimmingCharacters(in: .whitespaces).capitalized, emoji: newEmoji, colour: selectedColour, income: false, order: results.order)

                newName = ""
                newEmoji = ""

                availableColours = Color.colorArray
                expenseCategories.forEach { category in
                    if availableColours.contains(category.wrappedColour) {
                        availableColours.removeAll { $0 == category.wrappedColour }
                    }
                }

                if availableColours.isEmpty {
                    selectedColour = "#FFFFFF"
                } else {
                    selectedColour = availableColours[0]
                }
            }

            if budgetMode {
                dismiss()
            } else {
                focusedField = .emoji
                toastImage = "checkmark.circle.fill"
                positive = true
                showToast = true
            }
        }
    }

    init(income: Binding<Bool>, bottomSpacers: Bool, budgetMode: Bool = false) {
        _income = income
        self.budgetMode = budgetMode
        self.bottomSpacers = bottomSpacers
    }
}

struct EditCategoryAlert: View {
    let toEdit: CategoryModel
    @Binding var showRootToast: Bool
    @Binding var rootToastTitle: String
    @Binding var rootToastImage: String
    @Binding var positive: Bool

    let bottomSpacers: Bool

    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var systemColorScheme
    @Environment(CategoryViewModel.self) var categoryVM

    @Namespace var animation

    // existing categories

    var expenseCategories: [CategoryModel] { categoryVM.expenseCategories }

    // state
    @State private var newName = ""
    @State private var newEmoji = ""
    @State private var showingColourPicker = false
    @State private var selectedColour: String = "#FFFFFF"

    @FocusState var focusedField: FocusedField?

    enum FocusedField: Hashable {
        case emoji, name
    }

    // toasts
    @State var outcome = CategoryError.none
    @State var showToast = false
    @State var toastTitle = ""
    @State var toastImage = ""

    // delete mode
    @State private var deleteMode = false
    @State private var toDelete: CategoryModel?
    var alertMessage: String {
        String.localizedStringWithFormat(
            String.appLocalized("Delete '%@'?"),
            toDelete?.wrappedName ?? ""
        )
    }

    @State var showNativePicker: Bool = false
    @State var customSelectedColor = Color.white

    // haptic triggers (used to scope the modifier chain length)
    @State private var errorHaptic: Int = 0
    @State private var successHaptic: Int = 0

    var body: some View {
        VStack {
            VStack {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.callout.weight(.semibold))
                            
                            .foregroundStyle(Color.SubtitleText)
                            .padding(7)
                            .background(Color.SecondaryBackground, in: Circle())
                            .contentShape(Circle())
                    }

                    Spacer()

                    if showToast {
                        SBToast(title: toastTitle, systemImage: toastImage)
                            .transition(AnyTransition.opacity.combined(with: .move(edge: .top)))
                    } else {
                        Text(LocalizedStringKey(toEdit.income ? "Income" : "Expense"))
                            .font(.body.weight(.semibold))
                            
                    }

                    Spacer()

                    Button {
                        toDelete = toEdit
                    } label: {
                        Image(systemName: "trash.fill")
                            .font(.callout.weight(.semibold))
                            
                            .foregroundStyle(Color.AlertRed)
                            .padding(7)
                            .background(Color.AlertRed.opacity(0.23), in: Circle())
                            .contentShape(Circle())
                    }
                }
                .frame(height: 30)

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
                    if !toEdit.income {
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
                            ColourPickerView(selectedColor: $selectedColour, showMenu: $showingColourPicker, showNativePicker: $showNativePicker, expenseCategories: expenseCategories, toEdit: toEdit)
                        }
                    }

                    NormalTextField(text: $newName, placeholder: String.appLocalized("Category Name"), action: verification)
                        .focused($focusedField, equals: .name)
                        .padding(.horizontal, 15)
                        .padding(.vertical, 5)
                        .frame(height: 50)
                        .foregroundStyle(Color.PrimaryText)
                        .background {
                            RoundedRectangle(cornerRadius: SBRadius.card, style: .continuous)
                                .strokeBorder((focusedField == .name && !showingColourPicker) ? Color.SubtitleText : Color.clear, lineWidth: 2.2)
                                .background(RoundedRectangle(cornerRadius: SBRadius.card, style: .continuous).fill(Color.SecondaryBackground))
                        }

                    Button {
                        verification()
                    } label: {
                        Image(systemName: "checkmark")
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
        .sbToastDismissal($showToast)
        .fullScreenPresentation(item: $toDelete, onDismiss: {
            toDelete = nil
        }) { category in
            DeleteCategoryAlert(toDelete: category, deleted: $deleteMode)
        }
        .onChange(of: expenseCategories.count) { _, _ in
            if expenseCategories.count == 24 {
                dismiss()
            }
        }
        .onChange(of: customSelectedColor) { _, _ in
            selectedColour = customSelectedColor.toHex() ?? "#FFFFFF"
        }
        .colorPickerSheet(isPresented: $showNativePicker, selection: $customSelectedColor, supportsAlpha: false, title: "")
        .onChange(of: deleteMode) { _, _ in
            dismiss()
        }
        .onAppear {
            newName = toEdit.wrappedName
            newEmoji = toEdit.wrappedEmoji
            selectedColour = toEdit.wrappedColour
        }
        .modifier(ErrorSuccessHaptics(error: errorHaptic, success: successHaptic))
    }

    func verification() {
        let results = categoryVM.validateEdit(name: newName, emoji: newEmoji, exclude: toEdit)

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

            showToast = true
        } else {
            successHaptic &+= 1

            if toEdit.income {
                categoryVM.update(toEdit, name: newName.trimmingCharacters(in: .whitespaces).capitalized, emoji: newEmoji, colour: toEdit.colour)
            } else {
                categoryVM.update(toEdit, name: newName.trimmingCharacters(in: .whitespaces).capitalized, emoji: newEmoji, colour: selectedColour)
            }

            rootToastTitle = String.appFormatted("Edited %@", newName)
            rootToastImage = "checkmark.circle.fill"
            positive = true
            showRootToast = true

            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(150))
                dismiss()
            }
        }
    }
}

