//
//  TransactionCategoryGrid.swift
//  smartbud
//
//  Grid picker shown in place of the number pad. Tapping a tile selects it;
//  creating and managing categories are explicit actions below the grid.
//

import SwiftData
import SwiftUI

struct TransactionCategoryGrid: View {
    @Binding var category: CategoryModel?
    @Binding var showPicker: Bool
    @Binding var showingCategoryView: Bool
    let income: Bool

    @Environment(CategoryViewModel.self) private var categoryVM

    /// Read from the observed view model rather than `@Query`: the income
    /// flag can flip while the picker is open, and a query fixed in `init`
    /// would keep showing the old side's categories.
    private var categories: [CategoryModel] {
        income ? categoryVM.incomeCategories : categoryVM.expenseCategories
    }

    init(
        category: Binding<CategoryModel?>,
        showPicker: Binding<Bool>,
        showingCategoryView: Binding<Bool>,
        income: Bool
    ) {
        _category = category
        _showPicker = showPicker
        _showingCategoryView = showingCategoryView
        self.income = income
    }

    private let columns = [
        GridItem(.flexible(), spacing: SBSpace.extraSmall),
        GridItem(.flexible(), spacing: SBSpace.extraSmall)
    ]

    var body: some View {
        VStack(spacing: 0) {
            if categories.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: SBSpace.extraSmall) {
                        ForEach(categories) { item in
                            tile(item)
                        }
                    }
                    .padding(SBSpace.small)
                }
                .scrollIndicators(.hidden)
            }

            Divider()
            actions
        }
    }

    private var emptyState: some View {
        VStack(spacing: SBSpace.small) {
            Image(systemName: "square.grid.2x2")
                .font(.largeTitle)
                .foregroundStyle(Color.SubtitleText)
            Text(String.appLocalized("还没有分类"))
                .font(.headline)
            Text(String.appLocalized("添加常用分类，或创建自己的分类。"))
                .font(.subheadline)
                .foregroundStyle(Color.SubtitleText)
                .multilineTextAlignment(.center)
            Button(String.appLocalized("添加常用分类")) {
                categoryVM.seedStarterCategories()
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier(AccessibilityID.entrySeedCategories)
            .padding(.top, SBSpace.xxs)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(SBSpace.large)
    }

    private func tile(_ item: CategoryModel) -> some View {
        let selected = item == category
        return Button {
            withAnimation(.easeOut(duration: 0.15)) {
                category = item
            }
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(180))
                withAnimation { showPicker = false }
            }
        } label: {
            HStack(spacing: SBSpace.extraSmall) {
                Text(item.wrappedEmoji)
                    .font(.title3)
                Text(item.wrappedName)
                    .font(.body.weight(.medium))
                    .foregroundStyle(Color.PrimaryText)
                    .lineLimit(1)
                Spacer(minLength: 0)
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.accentColor)
                }
            }
            .padding(.horizontal, SBSpace.small)
            .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
            .background(
                Color.SecondaryBackground,
                in: RoundedRectangle(cornerRadius: SBRadius.control, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: SBRadius.control, style: .continuous)
                    .strokeBorder(
                        selected ? Color.accentColor : Color.Outline.opacity(0.5),
                        lineWidth: selected ? 2 : 0.5
                    )
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.wrappedName)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier(AccessibilityID.entryCategoryTile)
    }

    private var actions: some View {
        HStack(spacing: SBSpace.medium) {
            Button {
                showPicker = false
                showingCategoryView = true
            } label: {
                Label(String.appLocalized("新建分类"), systemImage: "plus")
                    .font(.body.weight(.medium))
                    .frame(minHeight: 44)
            }
            .buttonStyle(.borderless)

            Spacer(minLength: 0)

            Button {
                showPicker = false
                showingCategoryView = true
            } label: {
                Label(String.appLocalized("管理分类"), systemImage: "slider.horizontal.3")
                    .font(.body.weight(.medium))
                    .frame(minHeight: 44)
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, SBSpace.medium)
        .padding(.vertical, SBSpace.xxs)
    }
}
