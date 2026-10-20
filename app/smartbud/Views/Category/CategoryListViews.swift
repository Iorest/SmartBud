import CoreHaptics
import Foundation
import SwiftUI
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

struct CategoryListView: View {
    @Binding var income: Bool
    var mode: CategoryViewMode
    /// When set (transaction mode), a row tap picks the category instead of
    /// opening the edit sheet. Editing stays available via swipe actions.
    var onSelect: ((CategoryModel) -> Void)?

    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var systemColorScheme
    @Environment(CategoryViewModel.self) var categoryVM

    @AppStorage("bottomEdge", store: .appGroup) var bottomEdge: Double = 15

    @AppStorage("categorySuggestions", store: .appGroup) var showSuggestions: Bool = true

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
    // edit mode
    @State private var toEdit: CategoryModel?

    // toasts
    @Binding var showToast: Bool
    @Binding var toastTitle: String
    @Binding var toastImage: String
    @Binding var positive: Bool

    var sectionHeader: LocalizedStringKey {
        if income {
            return "INCOME CATEGORIES"
        } else {
            return "EXPENSE CATEGORIES"
        }
    }

    var body: some View {
        VStack(spacing: 5) {
            if showToast {
                SBToast(title: toastTitle, systemImage: toastImage, positive: positive)
                    .transition(AnyTransition.opacity.combined(with: .move(edge: .top)))
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
                                        .contentShape(Rectangle().inset(by: -5.5))
                                        .overlay {
                                            Image(systemName: "checkmark")
                                                .font(.callout.weight(.semibold))

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
                                        .contentShape(Rectangle().inset(by: -5.5))
                                        .overlay {
                                            Image(systemName: "arrow.up.arrow.down")
                                                .font(.callout.weight(.semibold))

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
                                        .contentShape(Rectangle().inset(by: -5.5))
                                .overlay {
                                    Image(systemName: showSuggestions ? "eye.slash" : "eye")
                                        .font(.callout.weight(.semibold))

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
                                        .contentShape(Rectangle().inset(by: -5.5))
                                .overlay {
                                    ZStack {
                                        Image(systemName: "arrow.right")
                                            .font(.callout.weight(.semibold))

                                            .foregroundStyle(!allCategories.isEmpty ? Color.IncomeGreen : Color.Outline.opacity(0.8))

                                        if allCategories.count == 0 {
                                            Circle()
                                                .stroke(Color.Outline.opacity(0.4), lineWidth: 1.3)
                                                .frame(width: 33, height: 33)
                                        .contentShape(Rectangle().inset(by: -5.5))
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
                            .font(.title3.weight(.medium))

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
                                        .contentShape(Rectangle().inset(by: -5.5))
                                    .overlay {
                                        Image(systemName: "chevron.left")
                                            .font(.body.weight(.semibold))

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
                                        .contentShape(Rectangle().inset(by: -5.5))
                                    .overlay {
                                        Image(systemName: "chevron.down")
                                            .font(.body.weight(.semibold))

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
                                        .contentShape(Rectangle().inset(by: -5.5))
                                .overlay {
                                    Image(systemName: showSuggestions ? "eye.slash" : "eye")
                                        .font(.callout.weight(.semibold))

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
                                        .contentShape(Rectangle().inset(by: -5.5))
                                        .overlay {
                                            Image(systemName: "checkmark")
                                                .font(.callout.weight(.semibold))

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
                                        .contentShape(Rectangle().inset(by: -5.5))
                                        .overlay {
                                            Image(systemName: "arrow.up.arrow.down")
                                                .font(.callout.weight(.semibold))

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
                            .font(.title3.weight(mode == .settings ? .semibold : .medium))

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
                                        .font(.largeTitle.weight(.light))

                                        .foregroundStyle(Color.SubtitleText)

                                    Group {
                                        if income {
                                            Text(LocalizedStringKey("no_income_categories"))
                                        } else {
                                            Text(LocalizedStringKey("no_expense_categories"))
                                        }
                                    }
                                    .font(.body.weight(.medium))

                                    .multilineTextAlignment(.center)
                                    .foregroundStyle(Color.SubtitleText)

                                    Button(String.appLocalized("添加常用分类")) {
                                        categoryVM.seedStarterCategories()
                                    }
                                    .buttonStyle(.bordered)
                                    .padding(.top, SBSpace.xxs)
                                }
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, 37)
                                .listRowBackground(Color.SettingsBackground)
                            } else {
                                ForEach(categories) { category in
                                    HStack(spacing: 10) {
                                        Text(category.wrappedEmoji)
                                            .font(.subheadline)

                                        Text(category.wrappedName)
                                            .font(.body)

                                            .lineLimit(1)
                                            .foregroundStyle(toDelete == category ? Color.AlertRed : Color.PrimaryText)

                                        Spacer()

                                        if !income {
                                            RoundedRectangle(cornerRadius: SBRadius.chip, style: .continuous)
                                                .fill(Color(hex: category.wrappedColour))
                                                .frame(width: 20, height: 20)
                                        }
                                    }
                                    .padding(.vertical, 5)
                                    .listRowBackground(Color.SettingsBackground)
                                    .listRowSeparatorTint(Color.Outline)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        if let onSelect {
                                            onSelect(category)
                                        } else {
                                            toEdit = category
                                        }
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

                        }

                        if showSuggestions {
                            SuggestedCategoriesView(income: income)
                        }
                    }
                    .scrollContentBackground(.hidden)
                    .scrollIndicators(.hidden)
                    #if os(iOS)
                    .environment(\.editMode, .constant(self.isEditing ? EditMode.active : EditMode.inactive))
                    #endif
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
        .fullScreenPresentation(isPresented: $deleteMode, onDismiss: {
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
                    Text(String.appFormatted("Delete '%@'?", deleteName))
                        .font(.title3.weight(.medium))
                        .foregroundStyle(Color.PrimaryText)

                    Text(String(
                        format: String.appLocalized("This action cannot be undone. %@ transactions are kept and become uncategorized."),
                        deleteName
                    ))
                        .font(.callout.weight(.medium))
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
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(height: 45)
                            .frame(maxWidth: .infinity)
                            .background(Color.AlertRed, in: RoundedRectangle(cornerRadius: SBRadius.chip, style: .continuous))
                    }
                    .padding(.bottom, 8)

                    Button {
                        withAnimation(.easeOut(duration: 0.7)) {
                            deleteMode = false
                            offset = 0
                        }

                    } label: {
                        Text(String.appLocalized("Cancel"))
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(Color.PrimaryText.opacity(0.9))
                            .frame(height: 45)
                            .frame(maxWidth: .infinity)
                            .background(Color.SecondaryBackground, in: RoundedRectangle(cornerRadius: SBRadius.chip, style: .continuous))
                    }
                }
                .padding(13)
                .systemCard(in: RoundedRectangle(cornerRadius: SBRadius.card, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: SBRadius.card).stroke(systemColorScheme == .dark ? Color.gray.opacity(0.1) : Color.clear, lineWidth: 1.3))
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
                    .presentationDetents([.medium, .large])
        }
        .sbToastDismissal($showToast)
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

    init(income: Binding<Bool>, mode: CategoryViewMode, onSelect: ((CategoryModel) -> Void)? = nil,
         showToast: Binding<Bool>, toastTitle: Binding<String>, toastImage: Binding<String>, positive: Binding<Bool>) {
        _income = income
        _showToast = showToast
        _toastTitle = toastTitle
        _toastImage = toastImage
        _positive = positive
        self.mode = mode
        self.onSelect = onSelect
    }
}
