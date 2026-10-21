//
//  CategoryView.swift
//  smartbud
//
//  Created by Iorest on 10/5/22.
//

import CoreHaptics
import Foundation
import SwiftUI
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

enum CategoryViewMode {
    case welcome, settings, transaction
}

struct CategoryView: View {
    var mode: CategoryViewMode
    /// Transaction mode only: called with the tapped category, then the sheet
    /// dismisses. Without this, tapping a row opened the editor and there was
    /// no way to actually pick a category for the transaction.
    var onSelect: ((CategoryModel) -> Void)?
    @Environment(\.dismiss) var dismiss
    @State var income = false

    @State var newCategory = false

    @Environment(CategoryViewModel.self) var categoryVM

    @State var showToast = false
    @State var toastTitle = ""
    @State var toastImage = ""
    @State var positive = false

    var disabled: Bool {
        income == false && categoryVM.expenseCategories.count >= 24
    }

    init(mode: CategoryViewMode, income: Bool = false, onSelect: ((CategoryModel) -> Void)? = nil) {
        self.mode = mode
        _income = State(initialValue: income)
        self.onSelect = onSelect
    }

    var body: some View {
        VStack(spacing: 5) {
            CategoryListView(income: $income, mode: mode,
                             onSelect: onSelect == nil ? nil : { category in
                                 onSelect?(category)
                                 dismiss()
                             },
                                 showToast: $showToast,
    toastTitle: $toastTitle,
    toastImage: $toastImage,
    positive: $positive
)

            HStack {
                Picker(String.appLocalized("Type"), selection: $income) {
                    Text(String.appLocalized("Expense")).tag(false)
                    Text(String.appLocalized("Income")).tag(true)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(maxWidth: SBControlWidth.segment)
                .layoutPriority(1)

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
                            .font(.subheadline.weight(.semibold))

                        Text(String.appLocalized("New"))
                            .font(.body.weight(.semibold))

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
                    .presentationDetents([.medium, .large])
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .ignoresSafeArea(.keyboard, edges: .all)
        .background(.clear)
        .onAppear {
            categoryVM.load()
        }
    }
}
