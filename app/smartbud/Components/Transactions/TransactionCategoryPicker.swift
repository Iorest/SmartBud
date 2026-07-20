//
//  TransactionCategoryPicker.swift
//  smartbud
//
//  Created by Rafael Soh on 20/11/23.
//

import Foundation
import SwiftUI
import SwiftData

struct NewCategoryPickerView: View {
    @Binding var category: CategoryModel?
    @Binding var showPicker: Bool
    @Binding var showingCategoryView: Bool
    @Query var categories: [CategoryModel]
    @Environment(\.colorScheme) var colorScheme

    let layout = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible())
    ]

    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVGrid(columns: layout, spacing: 10) {
                ForEach(categories) { item in
                    Button {
                        withAnimation {
                            category = item
                        }

                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            withAnimation {
                                showPicker = false
                            }
                        }
                    } label: {
                        HStack(spacing: 7) {
                            Text(item.wrappedEmoji)
                                .font(.system(.subheadline, design: .rounded))

                            Text(item.wrappedName)
                                .font(.system(.body, design: .rounded).weight(.semibold))
                                .lineLimit(1)
                        }
                        .id(item.id)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 9)
                        .foregroundStyle(Color(hex: item.wrappedColour))
                        .background(
                            Color(hex: item.wrappedColour).opacity(0.35),
                            in: RoundedRectangle(cornerRadius: 11.5, style: .continuous)
                        )
                        .overlay {
                            if item == category {
                                RoundedRectangle(cornerRadius: 11.5, style: .continuous)
                                    .strokeBorder(Color(hex: item.wrappedColour),
                                                  style: StrokeStyle(lineWidth: 2))
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .contentShape(Rectangle())
                    .accessibilityLabel(item.wrappedName)
                    .accessibilityAddTraits(item == category ? [.isButton, .isSelected] : .isButton)
                    .opacity(category != nil ? (category == item ? 1 : 0.5) : 1)

                }
            }
        }
        .keyboardAwareHeight(showToolbar: false)
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .overlay(alignment: .bottom) {
            Button {
                let impactMed = UIImpactFeedbackGenerator(style: .light)
                impactMed.impactOccurred()
                showPicker = false
                showingCategoryView = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "pencil")
                        .font(.system(.body, design: .rounded).weight(.semibold))
                    Text("Edit")
                        .font(.system(.body, design: .rounded).weight(.semibold))
                }
                .padding(.vertical, 9)
                .padding(.horizontal, 18)
                .foregroundStyle(Color.SubtitleText)
                .background {
                    RoundedRectangle(cornerRadius: 11.5, style: .continuous).fill(.clear)
                }
                .glassChip(in: RoundedRectangle(cornerRadius: 11.5, style: .continuous))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(localized: "Edit"))
            .padding(.bottom, 15)
        }

    }

    init(
        category: Binding<CategoryModel?>?, showPicker: Binding<Bool>, showSheet: Binding<Bool>,
        income: Bool
    ) {
        let incomeValue = income
        _categories = Query(filter: #Predicate<CategoryModel> { $0.income == incomeValue }, sort: [SortDescriptor(\CategoryModel.order, order: .reverse)])

        _category = category ?? Binding.constant(nil)
        _showPicker = showPicker
        _showingCategoryView = showSheet
    }
}
