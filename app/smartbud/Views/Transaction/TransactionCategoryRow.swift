//
//  TransactionCategoryRow.swift
//  smartbud
//
//  Category pill on the transaction form. Four states: no categories at all,
//  picker open ("Close"), a selected category chip, and the empty slot that
//  opens the picker. The three colour inputs are owned by the form so a
//  validation error can tint the pill without the row knowing why.
//

import SwiftUI

struct TransactionCategoryRow: View {
    let category: CategoryModel?
    let hasCategories: Bool
    @Binding var isPickerOpen: Bool

    let textColor: Color
    let backgroundColor: Color
    let outlineColor: Color
    /// Validation shake, driven by the form.
    let shake: Bool

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        if !hasCategories {
            emptyButton
        } else {
            Button {
                withAnimation(.easeInOut) { isPickerOpen.toggle() }
            } label: {
                Group {
                    if isPickerOpen {
                        closePill
                    } else if let category {
                        chip(category)
                    } else {
                        emptySlot
                            .offset(x: shake ? -5 : 0)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(accessibilityTitle)
        }
    }

    private var accessibilityTitle: String {
        if isPickerOpen {
            return String.appLocalized("Close")
        }
        if let category {
            return String.appLocalized("Category") + ": " + category.wrappedName
        }
        return String.appLocalized("Category")
    }

    private var closePill: some View {
        Text(String.appLocalized("Close"))
            .font(.body.weight(.semibold))
            .lineLimit(1)
            .padding(.vertical, 8.5)
            .padding(.horizontal, 10)
            .frame(width: buttonWidth)
            .foregroundStyle(Color.AlertRed)
            .background(Color.AlertRed.opacity(0.23),
                        in: RoundedRectangle(cornerRadius: SBRadius.input, style: .continuous))
    }

    private func chip(_ category: CategoryModel) -> some View {
        let color = Color(hex: category.wrappedColour)
        return HStack(spacing: 5) {
            Text(category.wrappedEmoji)
                .font(.footnote.weight(.semibold))

            Text(category.wrappedName)
                .font(.body.weight(.semibold))
                .lineLimit(1)
        }
        .padding(.vertical, 8.5)
        .padding(.horizontal, 10)
        .foregroundStyle(color)
        .background(color.opacity(0.35),
                    in: RoundedRectangle(cornerRadius: SBRadius.input, style: .continuous))
        .contentShape(Rectangle())
    }

    private var emptyButton: some View {
        Button {
            // Always use the grid picker, even before any category exists;
            // its empty state offers starter categories.
            withAnimation(.easeInOut) { isPickerOpen = true }
        } label: {
            emptyButtonLabel
        }
        .buttonStyle(.plain)
    }

    private var emptyButtonLabel: some View {
        HStack(spacing: 4) {
            Image(systemName: "plus")
                .font(.subheadline.weight(.semibold))

            Text(String.appLocalized("Category"))
                .font(.body.weight(.semibold))
                .lineLimit(1)
        }
        .padding(.vertical, 8.5)
        .padding(.horizontal, 10)
        .foregroundStyle(textColor)
        .background(backgroundColor,
                    in: RoundedRectangle(cornerRadius: SBRadius.input, style: .continuous))
        .contentShape(Rectangle())
        .overlay(
            RoundedRectangle(cornerRadius: SBRadius.input, style: .continuous)
                .strokeBorder(outlineColor, lineWidth: 1.5)
        )
        .drawingGroup()
        .offset(x: shake ? -5 : 0)
        .contentShape(Rectangle())
    }

    private var emptySlot: some View {
        HStack(spacing: 5.5) {
            Image(systemName: "circle.grid.2x2")
                .font(.subheadline.weight(.semibold))
                .symbolEffect(
                    .bounce.up.byLayer, options: .repeating.speed(0.5),
                    value: isPickerOpen)

            Text(String.appLocalized("Category"))
                .font(.body.weight(.semibold))
                .lineLimit(1)
        }
        .padding(.vertical, 8.5)
        .padding(.horizontal, 10)
        .frame(width: buttonWidth)
        .foregroundStyle(textColor)
        .background(backgroundColor,
                    in: RoundedRectangle(cornerRadius: SBRadius.input, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: SBRadius.input, style: .continuous)
                .strokeBorder(outlineColor, lineWidth: 1.5)
        )
        .drawingGroup()
    }

    private var buttonWidth: CGFloat {
        let fontSize = UIFont.getBodyFontSize(dynamicTypeSize: dynamicTypeSize)
        return "Category".widthOfRoundedString(size: fontSize, weight: .semibold) + 50
    }
}
