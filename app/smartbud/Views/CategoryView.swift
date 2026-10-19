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

