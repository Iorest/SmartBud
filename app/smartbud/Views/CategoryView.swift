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
                             showToast: $showToast, toastTitle: $toastTitle, toastImage: $toastImage, positive: $positive)

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
                            .font(.body.weight(.semibold))

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
                            .font(.body.weight(.semibold))

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
