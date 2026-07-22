//
//  TransactionCategoryPicker.swift
//  smartbud
//
//  Created by Iorest on 20/11/23.
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

    @State private var lightHaptic = 0

    let layout = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible())
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: layout, spacing: 10) {
                ForEach(categories) { item in
                    Button {
                        withAnimation {
                            category = item
                        }

                        Task { @MainActor in
                            try? await Task.sleep(for: .milliseconds(500))
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
        .scrollIndicators(.hidden)
        .keyboardAwareHeight(showToolbar: false)
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .overlay(alignment: .bottom) {
            Button {
                lightHaptic &+= 1
                showPicker = false
                showingCategoryView = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "pencil")
                        .font(.system(.body, design: .rounded).weight(.semibold))
                    Text(String.appLocalized("Edit"))
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
            .accessibilityLabel(String.appLocalized("Edit"))
            .padding(.bottom, 15)
        }
        .sensoryFeedback(.impact(weight: .light), trigger: lightHaptic)
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
