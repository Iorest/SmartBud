//
//  CategoryView.swift
//  smartbud
//
//  Created by Iorest on 10/5/22.
//

import CoreHaptics
import Foundation
import SwiftUI
import UIKit

enum CategoryViewMode {
    case welcome, settings, transaction
}

struct CategoryView: View {
    var mode: CategoryViewMode
//    @Environment(\.colorScheme) var colorScheme
    @State var income = false
    @Namespace var animation

    @State var newCategory = false

    @Environment(CategoryViewModel.self) var categoryVM

    @State var showToast = false
    @State var toastTitle = ""
    @State var toastImage = ""
    @State var positive = false

    var disabled: Bool {
        income == false && categoryVM.expenseCategories.count >= 24
    }

    var body: some View {
        VStack(spacing: 5) {
            CategoryListView(income: $income, mode: mode, showToast: $showToast, toastTitle: $toastTitle, toastImage: $toastImage, positive: $positive)

            HStack {
                HStack(spacing: 0) {
                    Button {
                        DispatchQueue.main.async {
                            withAnimation(.easeIn(duration: 0.15)) {
                                income = false
                            }
                        }
                    } label: {
                        Text(String.appLocalized("Expense"))
                            .font(.system(.body, design: .rounded).weight(.semibold))
                            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
//                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundStyle(income == false ? Color.PrimaryText : Color.SubtitleText)
                            .padding(6)
                            .padding(.horizontal, 8)
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
                            .font(.system(.body, design: .rounded).weight(.semibold))
                            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
//                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundStyle(income == true ? Color.PrimaryText : Color.SubtitleText)
                            .padding(6)
                            .padding(.horizontal, 8)
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
                .layoutPriority(1)
                .overlay(Capsule().stroke(Color.Outline.opacity(0.4), lineWidth: 1.3))

                Spacer()

                Button {
                    if disabled {
                        showToast = true
                        toastImage = "exclamationmark.triangle.fill"
                        toastTitle = String.appLocalized("Limit Exceeded")
                        positive = false
                    } else {
                        newCategory = true
                    }
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "plus")
                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
//                        .font(.system(size: 14.5, weight: .semibold, design: .rounded))

                        Text(String.appLocalized("New"))
                            .font(.system(.body, design: .rounded).weight(.semibold))
                            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
//                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .lineLimit(1)
                    }
                    .foregroundStyle(Color.PrimaryText)
                    .padding(6)
                    .padding(.horizontal, 4.5)
                    .background(Color.SecondaryBackground, in: Capsule())
                    .opacity(disabled ? 0.5 : 1)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(disabled)
            }
            .padding(25)
        }
        .sheet(isPresented: $newCategory) {
                NewCategoryAlert(income: $income, bottomSpacers: false)
                    .presentationDetents([.height(270)])
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .ignoresSafeArea(.keyboard, edges: .all)
        .background(.clear)
        .onAppear {
            categoryVM.load()
        }
    }
}

struct CategoryListView: View {
    @Binding var income: Bool
    var mode: CategoryViewMode

    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var systemColorScheme
    @Environment(CategoryViewModel.self) var categoryVM

    @AppStorage("bottomEdge", store: .appGroup) var bottomEdge: Double = 15

    @AppStorage("categorySuggestions", store: .appGroup) var showSuggestions: Bool = true
    @State var suggestionsToast = false

    @State private var offset: CGFloat = 0

    var categories: [CategoryModel] {
        income ? categoryVM.incomeCategories : categoryVM.expenseCategories
    }

    @State var isEditing = false

    var allCategories: [CategoryModel] {
        categoryVM.incomeCategories + categoryVM.expenseCategories
    }

    // delete mode
    @State private var deleteMode = false
    @State private var toDelete: CategoryModel?
    var alertMessage: String {
        String.localizedStringWithFormat(
            String.appLocalized("Delete '%@'?"),
            toDelete?.wrappedName ?? ""
        )
    }

    // edit mode
    @State private var toEdit: CategoryModel?

    // toasts
    @Binding var showToast: Bool
    @Binding var toastTitle: String
    @Binding var toastImage: String
    @Binding var positive: Bool

    var toastColor: Color {
        positive ? Color.IncomeGreen : Color.AlertRed
    }

    var sectionHeader: LocalizedStringKey {
        if income {
            return "INCOME CATEGORIES"
        } else {
            return "EXPENSE CATEGORIES"
        }
    }

    @Environment(\.dynamicTypeSize) var dynamicTypeSize

    var body: some View {
        VStack(spacing: 5) {
            if showToast {
                HStack(spacing: 6.5) {
                    Image(systemName: toastImage)
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
//                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(toastColor)

                    Text(toastTitle)
                        .font(.system(.body, design: .rounded).weight(.semibold))
                        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                        .lineLimit(1)
//                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(toastColor)
                }
                .padding(8)
                .background(toastColor.opacity(0.23), in: RoundedRectangle(cornerRadius: GlassRadius.chip, style: .continuous))
                .transition(AnyTransition.opacity.combined(with: .move(edge: .top)))
                .frame(maxWidth: 250)
                .frame(height: 35)
                .padding(20)
            } else {
                if mode == .welcome {
                    HStack(spacing: 8) {
                        if categories.count > 1 {
                            if isEditing {
                                Button {
                                    withAnimation {
                                        isEditing.toggle()
                                    }
                                } label: {
                                    Circle()
                                        .fill(Color.IncomeGreen.opacity(0.23))
                                        .frame(width: 33, height: 33)
                                        .overlay {
                                            Image(systemName: "checkmark")
                                                .font(.system(.callout, design: .rounded).weight(.semibold))
                                                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
//                                            .font(.system(size: 16, weight: .semibold))
                                                .foregroundStyle(Color.IncomeGreen)
                                        }
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(String.appLocalized("Done"))
                            } else {
                                Button {
                                    withAnimation {
                                        isEditing.toggle()
                                    }
                                } label: {
                                    Circle()
                                        .fill(Color.SecondaryBackground)
                                        .frame(width: 33, height: 33)
                                        .overlay {
                                            Image(systemName: "arrow.up.arrow.down")
                                                .font(.system(.callout, design: .rounded).weight(.semibold))
                                                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                                                .foregroundStyle(Color.SubtitleText)
                                        }
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(String.appLocalized("Reorder categories"))
                            }
                        }

                        Button {
                            withAnimation {
                                showSuggestions.toggle()
                            }
                        } label: {
                            Circle()
                                .fill(Color.SecondaryBackground)
                                .frame(width: 33, height: 33)
                                .overlay {
                                    Image(systemName: showSuggestions ? "eye.slash" : "eye")
                                        .font(.system(.callout, design: .rounded).weight(.semibold))
                                        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                                        .foregroundStyle(Color.SubtitleText)
                                        .offset(y: 0.8)
                                }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(showSuggestions ? String.appLocalized("Hide suggestions") : String.appLocalized("Show suggestions"))

                        Spacer()

                        Button {
                            if allCategories.count > 0 {
                                dismiss()
                            }
                        } label: {
                            Circle()
                                .fill(!allCategories.isEmpty ? Color.IncomeGreen.opacity(0.23) : Color.clear)
                                .frame(width: 33, height: 33)
                                .overlay {
                                    ZStack {
                                        Image(systemName: "arrow.right")
                                            .font(.system(.callout, design: .rounded).weight(.semibold))
                                            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                                            .foregroundStyle(!allCategories.isEmpty ? Color.IncomeGreen : Color.Outline.opacity(0.8))

                                        if allCategories.count == 0 {
                                            Circle()
                                                .stroke(Color.Outline.opacity(0.4), lineWidth: 1.3)
                                                .frame(width: 33, height: 33)
                                        }
                                    }
                                }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(String.appLocalized("Continue"))
                    }
                    .frame(height: 35)
                    .frame(maxWidth: .infinity)
                    .overlay {
                        Text(String.appLocalized("Categories"))
                            .font(.system(.title3, design: .rounded).weight(.medium))
                            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
//                            .font(.system(size: 20, weight: .medium, design: .rounded))
                    }
                    .padding(20)

                } else {
                    HStack(spacing: 8) {
                        if mode == .settings {
                            Button {
                                dismiss()
                            } label: {
                                Circle()
                                    .fill(Color.SecondaryBackground)
                                    .frame(width: 33, height: 33)
                                    .overlay {
                                        Image(systemName: "chevron.left")
                                            .font(.system(.body, design: .rounded).weight(.semibold))
                                            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
//                                        .font(.system(size: 18, weight: .semibold))
                                            .foregroundStyle(Color.SubtitleText)
                                            .offset(y: 0.8)
                                    }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(String.appLocalized("Back"))
                        } else {
                            Button {
                                dismiss()
                            } label: {
                                Circle()
                                    .fill(Color.SecondaryBackground)
                                    .frame(width: 33, height: 33)
                                    .overlay {
                                        Image(systemName: "chevron.down")
                                            .font(.system(.body, design: .rounded).weight(.semibold))
                                            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                                            .foregroundStyle(Color.SubtitleText)
                                            .offset(y: 0.8)
                                    }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(String.appLocalized("Close"))
                        }

                        Spacer()

                        Button {
                            withAnimation {
                                showSuggestions.toggle()
                            }
                        } label: {
                            Circle()
                                .fill(Color.SecondaryBackground)
                                .frame(width: 33, height: 33)
                                .overlay {
                                    Image(systemName: showSuggestions ? "eye.slash" : "eye")
                                        .font(.system(.callout, design: .rounded).weight(.semibold))
                                        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
//                                    .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(Color.SubtitleText)
                                        .offset(y: 0.8)
                                }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(showSuggestions ? String.appLocalized("Hide suggestions") : String.appLocalized("Show suggestions"))

                        if categories.count > 1 {
                            if isEditing {
                                Button {
                                    withAnimation {
                                        isEditing.toggle()
                                    }
                                } label: {
                                    Circle()
                                        .fill(Color.IncomeGreen.opacity(0.23))
                                        .frame(width: 33, height: 33)
                                        .overlay {
                                            Image(systemName: "checkmark")
                                                .font(.system(.callout, design: .rounded).weight(.semibold))
                                                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
//                                            .font(.system(size: 16, weight: .semibold))
                                                .foregroundStyle(Color.IncomeGreen)
                                        }
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(String.appLocalized("Done"))
                            } else {
                                Button {
                                    withAnimation {
                                        isEditing.toggle()
                                    }
                                } label: {
                                    Circle()
                                        .fill(Color.SecondaryBackground)
                                        .frame(width: 33, height: 33)
                                        .overlay {
                                            Image(systemName: "arrow.up.arrow.down")
                                                .font(.system(.callout, design: .rounded).weight(.semibold))
                                                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
//                                            .font(.system(size: 16, weight: .semibold))
                                                .foregroundStyle(Color.SubtitleText)
                                        }
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(String.appLocalized("Reorder categories"))
                            }
                        }
                    }
                    .frame(height: 35)
                    .frame(maxWidth: .infinity)
                    .overlay {
                        Text(String.appLocalized("Categories"))
                            .font(.system(.title3, design: .rounded).weight(mode == .settings ? .semibold : .medium))
                            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
//                            .font(.system(size: 20, weight: mode == .settings ? .semibold : .medium, design: .rounded))
                    }
                    .padding(20)
                }
            }

            VStack {
                    List {
                        Section(header: Text(sectionHeader).foregroundStyle(Color.SubtitleText)) {
                            if categories.isEmpty {
                                VStack(spacing: 10) {
                                    Image(systemName: "tray")
                                        .font(.system(.largeTitle, design: .rounded).weight(.light))
                                        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
//                                        .font(.system(size: 37, weight: .light))
                                        .foregroundStyle(Color.SubtitleText)

                                    Group {
                                        if income {
                                            Text(LocalizedStringKey("no_income_categories"))
                                        } else {
                                            Text(LocalizedStringKey("no_expense_categories"))
                                        }
                                    }
                                    .font(.system(.body, design: .rounded).weight(.medium))
                                    .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
//                                    .font(.system(size: 17, weight: .medium, design: .rounded))
                                    .italic()
                                    .multilineTextAlignment(.center)
                                    .foregroundStyle(Color.SubtitleText)
                                }
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, 37)
                                .listRowBackground(Color.SettingsBackground)
                            } else {
                                ForEach(categories) { category in
                                    HStack(spacing: 10) {
                                        Text(category.wrappedEmoji)
                                            .font(.system(.subheadline, design: .rounded))
                                            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
//                                            .font(.system(size: 15))
                                        Text(category.wrappedName)
                                            .font(.system(.body, design: .rounded))
                                            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
//                                            .font(.system(size: 18.5, weight: .regular, design: .rounded))
                                            .lineLimit(1)
                                            .foregroundStyle(toDelete == category ? Color.AlertRed : Color.PrimaryText)

                                        Spacer()

                                        if !income {
                                            RoundedRectangle(cornerRadius: GlassRadius.chip, style: .continuous)
                                                .fill(Color(hex: category.wrappedColour))
                                                .frame(width: 20, height: 20)
                                        }
                                    }
                                    .padding(.vertical, 5)
                                    .listRowBackground(Color.SettingsBackground)
                                    .listRowSeparatorTint(Color.Outline)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        toEdit = category
                                    }
                                    .accessibilityAddTraits(.isButton)
                                    .swipeActions(edge: .trailing) {
                                        Button {
                                            toDelete = category
                                        } label: {
                                            Image(systemName: "trash.fill")
                                        }
                                        .tint(Color.AlertRed)
                                    }
                                    .swipeActions(edge: .leading) {
                                        Button {
                                            toEdit = category
                                        } label: {
                                            Image(systemName: "pencil")
                                        }
                                        .tint(Color("Yellow"))
                                    }
                                }
                                .onMove(perform: moveItem)
                            }

//                                .onDelete(perform: deleteItem)
                        }

                        if showSuggestions {
                            SuggestedCategoriesView(income: income)
                        }
                    }
                    .scrollContentBackground(.hidden)
                    .scrollIndicators(.hidden)
                    .environment(\.editMode, .constant(self.isEditing ? EditMode.active : EditMode.inactive))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(.clear)
        .animation(.easeOut(duration: 0.2), value: showToast)
        .onChange(of: toDelete) { _, _ in
            if toDelete != nil {
                deleteMode = true
            }
        }
        .fullScreenCover(isPresented: $deleteMode, onDismiss: {
            toDelete = nil
        }) {
            ZStack(alignment: .bottom) {
                Color.clear
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        deleteMode = false
                    }
                    .accessibilityAddTraits(.isButton)

                VStack(alignment: .leading, spacing: 1.5) {
                    let deleteName = toDelete?.wrappedName ?? ""
                    Text(String(localized: "Delete '\(deleteName)'?"))
                        .font(.system(size: 20, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.PrimaryText)

                    Text(String(localized: "This action cannot be undone, and all \(deleteName) transactions would be deleted."))
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.SubtitleText)
                        .padding(.bottom, 15)

                    Button {
                        withAnimation {
                            if let gonnaDelete = toDelete {
                                categoryVM.delete(gonnaDelete)
                            }
                        }

                        toDelete = nil
                        deleteMode = false

                    } label: {
                        Text(String.appLocalized("Delete"))
                            .font(.system(size: 20, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                            .frame(height: 45)
                            .frame(maxWidth: .infinity)
                            .background(Color.AlertRed, in: RoundedRectangle(cornerRadius: GlassRadius.chip, style: .continuous))
                    }
                    .padding(.bottom, 8)

                    Button {
                        withAnimation(.easeOut(duration: 0.7)) {
                            deleteMode = false
                            offset = 0
                        }

                    } label: {
                        Text(String.appLocalized("Cancel"))
                            .font(.system(size: 20, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.PrimaryText.opacity(0.9))
                            .frame(height: 45)
                            .frame(maxWidth: .infinity)
                            //                        .background(Color("13").opacity(0.23), in: RoundedRectangle(cornerRadius: GlassRadius.chip, style: .continuous))
                            .background(Color.SecondaryBackground, in: RoundedRectangle(cornerRadius: GlassRadius.chip, style: .continuous))
                    }
                }
                .padding(13)
                .glassCard(in: RoundedRectangle(cornerRadius: GlassRadius.card, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: GlassRadius.card).stroke(systemColorScheme == .dark ? Color.gray.opacity(0.1) : Color.clear, lineWidth: 1.3))
                .offset(y: offset)
                .gesture(
                    DragGesture()
                        .onChanged { gesture in
                            if gesture.translation.height < 0 {
                                offset = gesture.translation.height / 3
                            } else {
                                offset = gesture.translation.height
                            }
                        }
                        .onEnded { value in
                            if value.translation.height > 20 {
                                deleteMode = false
                                offset = 0
                            } else {
                                withAnimation {
                                    offset = 0
                                }
                            }
                        }
                )
                .padding(.horizontal, 17)
                .padding(.bottom, bottomEdge == 0 ? 13 : bottomEdge)
            }
            .ignoresSafeArea(.all)
            .background(BackgroundBlurView())
        }
        .sheet(item: $toEdit, onDismiss: {
            toEdit = nil
        }) { category in
                EditCategoryAlert(toEdit: category, showRootToast: $showToast, rootToastTitle: $toastTitle, rootToastImage: $toastImage, positive: $positive, bottomSpacers: false)
                    .presentationDetents([.height(270)])
        }
        .onChange(of: showToast) { _, newValue in
            if newValue {
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(2))
                    showToast = false
                }
            }
        }
        .onChange(of: showSuggestions) { _, newValue in
            if !newValue {
                toastTitle = String.appLocalized("Suggestions Hidden")
                toastImage = "eye.slash"
                showToast = true
                positive = true
            }
        }
    }

    private func moveItem(at sets: IndexSet, destination: Int) {
        categoryVM.reorder(from: sets, to: destination, income: income)
    }

    init(income: Binding<Bool>, mode: CategoryViewMode, showToast: Binding<Bool>, toastTitle: Binding<String>, toastImage: Binding<String>, positive: Binding<Bool>) {
        _income = income
        _showToast = showToast
        _toastTitle = toastTitle
        _toastImage = toastImage
        _positive = positive
        self.mode = mode
    }
}

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
                                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
//                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(toastColor)

                            Text(toastTitle)
                                .font(.system(.callout, design: .rounded).weight(.semibold))
                                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
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
                                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
//                                .font(.system(size: 18, weight: .semibold, design: .rounded))
                                .padding(.top, 4)
                        } else if budgetMode {
                            Text(String.appLocalized("Expense Category"))
                                .font(.system(.body, design: .rounded).weight(.semibold))
                                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
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
                                        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
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
                                        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
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
                            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
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
                            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
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
                            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
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
                                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
//                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Color.AlertRed)

                            Text(toastTitle)
                                .font(.system(.callout, design: .rounded).weight(.semibold))
                                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
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
                            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
//                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                    }

                    Spacer()

                    Button {
                        toDelete = toEdit
                    } label: {
                        Image(systemName: "trash.fill")
                            .font(.system(.callout, design: .rounded).weight(.semibold))
                            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
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
                            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
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

struct DeleteCategoryAlert: View {
    @Environment(CategoryViewModel.self) var categoryVM
    @Environment(\.dismiss) var dismiss
    let toDelete: CategoryModel
    @Binding var deleted: Bool
    @Environment(\.colorScheme) var systemColorScheme

    @AppStorage("bottomEdge", store: .appGroup) var bottomEdge: Double = 15

    @State private var offset: CGFloat = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.clear
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .onTapGesture {
                    dismiss()
                }
                .accessibilityAddTraits(.isButton)

            VStack(alignment: .leading, spacing: 1.5) {
                Text(String(localized: "Delete '\(toDelete.wrappedName)'?"))
                    .font(.system(.title2, design: .rounded).weight(.medium))
                    .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
//                    .font(.system(size: 20, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.PrimaryText)

                Text(String.appLocalized("This action cannot be undone."))
                    .font(.system(.title3, design: .rounded).weight(.medium))
                    .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
//                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.SubtitleText)
                    .padding(.bottom, 15)
                    .accessibilityHidden(true)

                Button {
                    deleted = true
                    dismiss()

                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(500))
                        withAnimation {
                            categoryVM.delete(toDelete)
                        }
                    }

                } label: {
                    Text(String.appLocalized("Delete"))
                        .font(.system(.title3, design: .rounded).weight(.semibold))
                        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                        .foregroundStyle(.white)
                        .frame(height: 45)
                        .frame(maxWidth: .infinity)
                        .background(Color.AlertRed, in: RoundedRectangle(cornerRadius: GlassRadius.chip, style: .continuous))
                }
                .padding(.bottom, 8)

                Button {
                    withAnimation(.easeOut(duration: 0.7)) {
                        dismiss()
                    }

                } label: {
                    Text(String.appLocalized("Cancel"))
                        .font(.system(.title3, design: .rounded).weight(.semibold))
                        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
//                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.PrimaryText.opacity(0.9))
                        .frame(height: 45)
                        .frame(maxWidth: .infinity)
                        .background(Color.SecondaryBackground, in: RoundedRectangle(cornerRadius: GlassRadius.chip, style: .continuous))
                }
            }
            .padding(13)
//            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: GlassRadius.card, style: .continuous))
            .glassCard(in: RoundedRectangle(cornerRadius: GlassRadius.card, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: GlassRadius.card).stroke(systemColorScheme == .dark ? Color.gray.opacity(0.1) : Color.clear, lineWidth: 1.3))
            .offset(y: offset)
            .gesture(
                DragGesture()
                    .onChanged { gesture in
                        if gesture.translation.height < 0 {
                            offset = gesture.translation.height / 3
                        } else {
                            offset = gesture.translation.height
                        }
                    }
                    .onEnded { value in
                        if value.translation.height > 20 {
                            dismiss()
                        } else {
                            withAnimation {
                                offset = 0
                            }
                        }
                    }
            )
//            .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .local)
//                .onEnded({ value in
//                    if value.translation.height > 0 {
//                        dismiss()
//                    }
//                }))
            .padding(.horizontal, 17)
            .padding(.bottom, bottomEdge == 0 ? 13 : bottomEdge)
        }
        .ignoresSafeArea(.all)
        .background(BackgroundBlurView())
    }
}

struct SuggestedCategoriesView: View {
    let income: Bool
    @Environment(CategoryViewModel.self) var categoryVM

    var categories: [CategoryModel] {
        income ? categoryVM.incomeCategories : categoryVM.expenseCategories
    }

    var nameArray: [String] {
        var emptyArray = [String]()

        categories.forEach { category in
            emptyArray.append(category.wrappedName)
        }

        return emptyArray
    }

    var emojiArray: [String] {
        var emptyArray = [String]()

        categories.forEach { category in
            emptyArray.append(category.wrappedEmoji)
        }

        return emptyArray
    }

    var suggestions: [SuggestedCategory] {
        var holding = [SuggestedCategory]()

        if income {
            SuggestedCategory.incomes.forEach { category in
                if !nameArray.contains(category.name) && !emojiArray.contains(category.emoji) {
                    holding.append(category)
                }
            }
        } else {
            SuggestedCategory.expenses.forEach { category in
                if !nameArray.contains(category.name) && !emojiArray.contains(category.emoji) {
                    holding.append(category)
                }
            }
        }

        return holding
    }

    @State private var availableColours: [String] = Color.colorArray
    @State private var selectedColour = "1"
    @State private var lightHaptic: Int = 0

    var body: some View {
        Group {
            if !suggestions.isEmpty {
                Section(header: Text(String.appLocalized("SUGGESTED")).foregroundStyle(Color.SubtitleText)) {
                    ForEach(suggestions, id: \.self) { category in
                        HStack(spacing: 8) {
                            Text(category.emoji)
//                            .font(.system(size: 15))
                                .font(.system(.subheadline, design: .rounded))
                                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                            Text(LocalizedStringKey(category.name))
                                .font(.system(.body, design: .rounded))
                                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
//                            .font(.system(size: 18.5, weight: .regular, design: .rounded))
                                .lineLimit(1)

                            Spacer()

                            Image(systemName: "plus")
                                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
//                            .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Color.SubtitleText)
                                .padding(4)
                                .background(Color.SecondaryBackground, in: Circle())
                                .contentShape(Circle())
                        }
                        .padding(.vertical, 5)
                        .foregroundStyle(Color.PrimaryText)
                        .listRowBackground(Color.SettingsBackground)
                        .listRowSeparatorTint(Color.Outline)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            // double check

                            let (_, outcome, order) = categoryVM.validate(name: category.name, emoji: category.emoji, income: income)


                            if outcome != .none {
                                return
                            }

                            lightHaptic &+= 1

                            if !income {
                                _ = categoryVM.create(name: NSLocalizedString(category.name, comment: "category name"), emoji: category.emoji, colour: selectedColour, income: false, order: order)

                                availableColours = Color.colorArray
                                categories.forEach { category in
                                    if availableColours.contains(category.wrappedColour) {
                                        availableColours.removeAll { $0 == category.wrappedColour }
                                    }
                                }

                                if availableColours.isEmpty {
                                    selectedColour = "#FFFFFF"
                                } else {
                                    selectedColour = availableColours[0]
                                }
                            } else {
                                _ = categoryVM.create(name: NSLocalizedString(category.name, comment: "category name"), emoji: category.emoji, colour: "#76FBB0", income: true, order: order)
                            }
                        }
                        .accessibilityAddTraits(.isButton)
                    }
                }
                .onAppear {
                    if !income {
                        categories.forEach { category in
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
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: lightHaptic)
    }

    init(income: Bool) {
        self.income = income
    }
}

class UIEmojiTextField: UITextField {
    override var textInputMode: UITextInputMode? {
        .activeInputModes.first(where: { $0.primaryLanguage == "emoji" })
    }

    override func caretRect(for _: UITextPosition) -> CGRect {
        return CGRect.zero
    }
}

struct EmojiTextField: UIViewRepresentable {
    @Binding var text: String
    var placeholder: String = ""

    func makeUIView(context: Context) -> UIEmojiTextField {
        let emojiTextField = UIEmojiTextField()
        emojiTextField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        emojiTextField.placeholder = placeholder
        emojiTextField.text = text
        emojiTextField.delegate = context.coordinator
        emojiTextField.font = UIFont(name: "HelveticaNeue", size: 50)
        emojiTextField.textAlignment = .center
        emojiTextField.endFloatingCursor()
        emojiTextField.becomeFirstResponder()
        return emojiTextField
    }

    func updateUIView(_ uiView: UIEmojiTextField, context _: Context) {
        uiView.text = text
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    class Coordinator: NSObject, UITextFieldDelegate {
        var parent: EmojiTextField

        init(parent: EmojiTextField) {
            self.parent = parent
        }

        func textFieldDidChangeSelection(_ textField: UITextField) {
            DispatchQueue.main.async { [weak self] in
                self?.parent.text = textField.text ?? ""
            }
        }
    }
}

struct NormalTextField: UIViewRepresentable {
    @Binding var text: String
    var placeholder: String = ""
    var action: () -> Void

    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField(frame: .zero)
        textField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textField.placeholder = placeholder
        textField.autocapitalizationType = .words
        textField.text = text
        textField.delegate = context.coordinator

        textField.font = UIFont.roundedSpecial(ofStyle: .title2, weight: .medium, size: 17)
//
//        UIFont.rounded(ofSize: 20, weight: .medium)
        return textField
    }

    func updateUIView(_ uiView: UITextField, context _: Context) {
        uiView.text = text
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    class Coordinator: NSObject, UITextFieldDelegate {
        var parent: NormalTextField

        init(parent: NormalTextField) {
            self.parent = parent
        }

        func textFieldDidChangeSelection(_ textField: UITextField) {
            DispatchQueue.main.async { [weak self] in
                self?.parent.text = textField.text ?? ""
            }
        }

        func textFieldShouldReturn(_: UITextField) -> Bool {
            parent.action()

            return true
        }
    }
}

struct ColourPickerView: View {
    var selectedColours: [String]

    @Binding var showMenu: Bool
    @Binding var selectedColour: String

    @Binding var showNativePicker: Bool

    @State var customMode: Bool = false
    @State var customSelectedColor = Color.white

    @State var testing = false
    let columns = [
        GridItem(.fixed(40), spacing: 6),
        GridItem(.fixed(40), spacing: 6),
        GridItem(.fixed(40), spacing: 6),
        GridItem(.fixed(40), spacing: 6),
        GridItem(.fixed(40), spacing: 6),
        GridItem(.fixed(40))
    ]

    @AppStorage("colourScheme", store: .appGroup) var colourScheme: Int = 0

    @Environment(\.colorScheme) var systemColorScheme

    var darkMode: Bool {
        (colourScheme == 0 && systemColorScheme == .dark) || colourScheme == 2
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: 6) {
            ForEach(Color.colorArray, id: \.self) { suggestedColor in
                if suggestedColor == "#" {
                    Button {
                        showMenu = false
                        showNativePicker = true
                    } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: GlassRadius.chip)
                                .fill(AngularGradient(gradient: Gradient(colors: [.red, .yellow, .green, .blue, .purple, .pink]), center: .center))

                            RoundedRectangle(cornerRadius: GlassRadius.pill)
                                .fill(darkMode ? Color("AlwaysDarkBackground") : Color("AlwaysLightBackground"))
                                .padding(4)

                            RoundedRectangle(cornerRadius: 3)
                                .fill(customSelectedColor)
                                .padding(8)

                            if customMode {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundStyle(customSelectedColor.luminance() > 0.5 ? Color.black : Color.white)
                            } else {
                                Image(systemName: "plus")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(Color.black)
                            }
                        }
                        .frame(width: 40, height: 40, alignment: .center)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(String.appLocalized("Custom color"))
                } else {
                    Button {
                        if !selectedColours.contains(suggestedColor) {
                            withAnimation {
                                selectedColour = suggestedColor
                                customMode = false
                                showMenu = false
                            }
                        }
                    } label: {
                        RoundedRectangle(cornerRadius: GlassRadius.chip, style: .continuous)
                            .fill(Color(hex: suggestedColor))
                            .frame(height: 40)
                            .opacity(selectedColours.contains(suggestedColor) ? 0.2 : 1)
                            .overlay {
                                if selectedColour == suggestedColor && !customMode {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundStyle(Color.black)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(6)
        .frame(width: 282)
        .background(RoundedRectangle(cornerRadius: GlassRadius.chip).fill(darkMode ? Color("AlwaysDarkBackground") : Color("AlwaysLightBackground")).shadow(color: darkMode ? Color.clear : Color.gray.opacity(0.25), radius: 6))
        .overlay(RoundedRectangle(cornerRadius: GlassRadius.chip).stroke(darkMode ? Color.gray.opacity(0.1) : Color.clear, lineWidth: 1.3))
    }

    init(selectedColor: Binding<String>, showMenu: Binding<Bool>, showNativePicker: Binding<Bool>, expenseCategories: [CategoryModel], toEdit: CategoryModel? = nil) {
        _selectedColour = selectedColor
        _showMenu = showMenu
        _showNativePicker = showNativePicker

        if !Color.colorArray.contains(selectedColor.wrappedValue) {
            _customMode = State(initialValue: true)
            _customSelectedColor = State(initialValue: Color(hex: selectedColor.wrappedValue))
        }

        var selectedColours = [String]()

        expenseCategories.forEach { category in
            selectedColours.append(category.wrappedColour)
        }

        if let editted = toEdit {
            selectedColours.removeAll { $0 == editted.wrappedColour }
        }

        self.selectedColours = selectedColours
    }
}

// Combines two .sensoryFeedback modifiers into a single .modifier() call so the
// trailing modifier chain on category alerts stays short enough for type inference.
private struct ErrorSuccessHaptics: ViewModifier {
    let error: Int
    let success: Int

    func body(content: Content) -> some View {
        content
            .sensoryFeedback(.error, trigger: error)
            .sensoryFeedback(.success, trigger: success)
    }
}
