import CoreHaptics
import Foundation
import SwiftUI
import UIKit

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

    var toastColor: Color {
        positive ? Color.IncomeGreen : Color.AlertRed
    }

    var addButtonDisabled: Bool {
        return newName.trimmingCharacters(in: .whitespacesAndNewlines) == "" || newEmoji == ""
    }

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
                        HStack(spacing: 5) {
                            Image(systemName: toastImage)
                                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                                
//                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(toastColor)

                            Text(toastTitle)
                                .font(.system(.callout, design: .rounded).weight(.semibold))
                                
                                .lineLimit(1)
//                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundStyle(toastColor)
                        }
                        .padding(6)
                        .background(toastColor.opacity(0.23), in: RoundedRectangle(cornerRadius: GlassRadius.chip, style: .continuous))
                        .transition(AnyTransition.opacity.combined(with: .move(edge: .top)))
                        .frame(maxWidth: 200)
                    } else {
                        if expenseCategories.count == 24 {
                            Text(String.appLocalized("Income Category"))
                                .font(.system(.body, design: .rounded).weight(.semibold))
                                
//                                .font(.system(size: 18, weight: .semibold, design: .rounded))
                                .padding(.top, 4)
                        } else if budgetMode {
                            Text(String.appLocalized("Expense Category"))
                                .font(.system(.body, design: .rounded).weight(.semibold))
                                
//                                .font(.system(size: 18, weight: .semibold, design: .rounded))
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
                                        .font(.system(.callout, design: .rounded).weight(.semibold))
                                        
//                                    .font(.system(size: 16, weight: .semibold, design: .rounded))
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
                                        .font(.system(.callout, design: .rounded).weight(.semibold))
                                        
//                                    .font(.system(size: 16, weight: .semibold, design: .rounded))
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
                            .font(.system(.callout, design: .rounded).weight(.semibold))
                            
//                            .font(.system(size: 16, weight: .semibold))
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
                            RoundedRectangle(cornerRadius: GlassRadius.card, style: .continuous)
                                .strokeBorder((focusedField == .emoji && !showingColourPicker) ? Color.SubtitleText : Color.clear, lineWidth: 2.2)
                                .background(RoundedRectangle(cornerRadius: GlassRadius.card, style: .continuous).fill(Color.SecondaryBackground))
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
                            RoundedRectangle(cornerRadius: GlassRadius.chip, style: .continuous)
                                .fill(Color(hex: selectedColour))
                                .padding(8)
                                .background(Color.SecondaryBackground, in: RoundedRectangle(cornerRadius: GlassRadius.card, style: .continuous))
                                .frame(width: 50, height: 50)
                                .overlay {
                                    if showingColourPicker {
                                        RoundedRectangle(cornerRadius: GlassRadius.card, style: .continuous)
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
                            RoundedRectangle(cornerRadius: GlassRadius.card, style: .continuous)
                                .strokeBorder((focusedField == .name && !showingColourPicker) ? Color.SubtitleText : Color.clear, lineWidth: 2.2)
                                .background(RoundedRectangle(cornerRadius: GlassRadius.card, style: .continuous).fill(Color.SecondaryBackground))
                        }
                    //
                    Button {
                        verification()
                    } label: {
                        Image(systemName: "plus")
                            .foregroundStyle(Color.LightIcon)
                            .font(.system(.title3, design: .rounded).weight(.semibold))
                            
//                            .font(.system(size: 20, weight: .semibold))
                            .frame(width: 50, height: 50)
                            .background(Color.DarkBackground, in: RoundedRectangle(cornerRadius: GlassRadius.card, style: .continuous))
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
        .onChange(of: showToast) { _, newValue in
            if newValue {
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(2))
                    showToast = false
                }
            }
        }
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
            toastTitle = String(localized: "Added \(newName)")

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
                            .font(.system(.callout, design: .rounded).weight(.semibold))
                            
//                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.SubtitleText)
                            .padding(7)
                            .background(Color.SecondaryBackground, in: Circle())
                            .contentShape(Circle())
                    }

                    Spacer()

                    if showToast {
                        HStack(spacing: 5) {
                            Image(systemName: toastImage)
                                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                                
//                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Color.AlertRed)

                            Text(toastTitle)
                                .font(.system(.callout, design: .rounded).weight(.semibold))
                                
                                .lineLimit(1)
//                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundStyle(Color.AlertRed)
                        }
                        .padding(6)
                        .background(Color.AlertRed.opacity(0.23), in: RoundedRectangle(cornerRadius: GlassRadius.chip, style: .continuous))
                        .transition(AnyTransition.opacity.combined(with: .move(edge: .top)))
                        .frame(maxWidth: 200)
                    } else {
                        Text(LocalizedStringKey(toEdit.income ? "Income" : "Expense"))
                            .font(.system(.body, design: .rounded).weight(.semibold))
                            
//                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                    }

                    Spacer()

                    Button {
                        toDelete = toEdit
                    } label: {
                        Image(systemName: "trash.fill")
                            .font(.system(.callout, design: .rounded).weight(.semibold))
                            
//                            .font(.system(size: 16, weight: .semibold))
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
                            RoundedRectangle(cornerRadius: GlassRadius.card, style: .continuous)
                                .strokeBorder((focusedField == .emoji && !showingColourPicker) ? Color.SubtitleText : Color.clear, lineWidth: 2.2)
                                .background(RoundedRectangle(cornerRadius: GlassRadius.card, style: .continuous).fill(Color.SecondaryBackground))
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
                            RoundedRectangle(cornerRadius: GlassRadius.chip, style: .continuous)
                                .fill(Color(hex: selectedColour))
                                .padding(8)
                                .background(Color.SecondaryBackground, in: RoundedRectangle(cornerRadius: GlassRadius.card, style: .continuous))
                                .frame(width: 50, height: 50)
                                .overlay {
                                    if showingColourPicker {
                                        RoundedRectangle(cornerRadius: GlassRadius.card, style: .continuous)
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
                            RoundedRectangle(cornerRadius: GlassRadius.card, style: .continuous)
                                .strokeBorder((focusedField == .name && !showingColourPicker) ? Color.SubtitleText : Color.clear, lineWidth: 2.2)
                                .background(RoundedRectangle(cornerRadius: GlassRadius.card, style: .continuous).fill(Color.SecondaryBackground))
                        }

                    Button {
                        verification()
                    } label: {
                        Image(systemName: "checkmark")
                            .foregroundStyle(Color.LightIcon)
                            .font(.system(.title3, design: .rounded).weight(.semibold))
                            
//                            .font(.system(size: 20, weight: .semibold))
                            .frame(width: 50, height: 50)
                            .background(Color.DarkBackground, in: RoundedRectangle(cornerRadius: GlassRadius.card, style: .continuous))
                    }
                }
            }
            .padding(13)
            .frame(maxHeight: bottomSpacers ? 350 : .infinity)
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .background(.clear)
        .animation(.easeOut(duration: 0.2), value: showToast)
        .onChange(of: showToast) { _, newValue in
            if newValue {
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(2))
                    showToast = false
                }
            }
        }
        .fullScreenCover(item: $toDelete, onDismiss: {
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

            rootToastTitle = String(localized: "Edited \(newName)")
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

