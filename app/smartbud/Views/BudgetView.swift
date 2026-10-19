//
//  BudgetView.swift
//  smartbud
//
//  Created by Iorest on 20/5/22.
//

import Foundation
import SwiftUI
import SwiftData

struct BudgetView: View {
    @Query private var categories: [CategoryModel]
    @Query private var budgets: [BudgetModel]
    @Query private var mainBudget: [MainBudgetModel]

    var body: some View {
        if categories.isEmpty && budgets.isEmpty && mainBudget.isEmpty {
            VStack(spacing: 5) {
                Image("category-3")
                    .resizable()
                    .frame(width: 75, height: 75)
                    .padding(.bottom, 20)

                Text("Budget Your Finances")
                    .font(.system(.title2, design: .rounded).weight(.medium))
//                    .font(.system(size: 23.5, weight: .medium, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.PrimaryText.opacity(0.8))

                Text("Link budgets to categories and set appropriate expenditure goals")
                    .font(.system(.body, design: .rounded).weight(.medium))
//                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.SubtitleText.opacity(0.7))
            }
            .padding(.horizontal, 30)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        } else {
            ActualBudgetView()
        }
    }
}

struct ActualBudgetView: View {
    @Environment(\.colorScheme) var colorScheme
    @State private var showInfo = false

    @Query(sort: [SortDescriptor(\BudgetModel.dateCreated)]) private var budgets: [BudgetModel]
    @Query private var mainBudget: [MainBudgetModel]
    @Environment(BudgetViewModel.self) var budgetVM
    @Environment(TabBarManager.self) var tabBarManager

    @State var newBudget = false

    @State private var showMenu = false

    @State private var toDelete: BudgetModel?
    @State private var toEdit: BudgetModel?

    let layout = [
        GridItem(.flexible(), spacing: 15),
        GridItem(.flexible(), spacing: 15)
    ]

    @AppStorage("budgetViewStyle", store: .appGroup) var budgetRows: Bool = false

    @Namespace var animation

    @State var date = Date.now

    var body: some View {
        NavigationStack {
            ZStack {
                AppGlassBackground()
                    .ignoresSafeArea(.all)

                VStack(spacing: 0) {
                    HStack {
                        Text("Budgets")
                            .font(.system(.title, design: .rounded).weight(.semibold))
//                            .font(.system(size: 25, weight: .semibold, design: .rounded))
                            .accessibility(addTraits: .isHeader)

                        Button {
                            newBudget = true
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(.subheadline, design: .rounded).weight(.semibold))
//                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Color.SubtitleText)
                                .padding(4)
                                .glassChip(in: Circle())
                                .contentShape(Circle())
                        }

                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 20)
                    .padding(.horizontal, 30)
                    .padding(.bottom, 20)

                    if !budgets.isEmpty || !mainBudget.isEmpty {
                        ScrollView(showsIndicators: false) {
                            VStack {
                                if let first = mainBudget.first {
                                    NavigationLink(value: first) {
                                        if budgets.count == 0 {
                                            MainBudgetView(budget: first, solo: true)
                                                .padding(.horizontal, 25)
                                                .padding(.bottom, 15)
                                        } else {
                                            MainBudgetView(budget: first, solo: false)
                                                .padding(.horizontal, 25)
                                                .padding(.bottom, 15)
                                        }
                                    }
                                }

                                if budgetRows {
                                    VStack(spacing: 10) {
                                        ForEach(budgets, id: \.self) { budget in
                                            NavigationLink(value: budget) {
                                                SingleBudgetView(budget: budget, toDelete: $toDelete, toEdit: $toEdit, budgetRows: budgetRows)
                                            }
                                        }
                                    }

                                } else {
                                    LazyVGrid(columns: layout, spacing: 15) {
                                        ForEach(budgets, id: \.self) { budget in
                                            NavigationLink(value: budget) {
                                                SingleBudgetView(budget: budget, toDelete: $toDelete, toEdit: $toEdit, budgetRows: budgetRows)
                                            }
                                        }
                                    }
                                    .padding(.horizontal, 25)
                                    .padding(5)
                                }
                            }
                            .padding(.bottom, 70)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        VStack(spacing: 5) {
                            Spacer()
                            Text("🙈")
                                .font(.system(.largeTitle, design: .rounded))
//                                .font(.system(size: 45))
                                .padding(.bottom, 9)

                            Text("No Budgets Found")
                                .font(.system(.title2, design: .rounded).weight(.medium))
//                                .font(.system(size: 23.5, weight: .medium, design: .rounded))
                                .multilineTextAlignment(.center)
                                .foregroundStyle(Color.PrimaryText.opacity(0.8))

                            Text("Add your first budget today!")
                                .font(.system(.body, design: .rounded).weight(.medium))
                                .multilineTextAlignment(.center)
                                .foregroundStyle(Color.SubtitleText)

                            Button {
                                newBudget = true
                            } label: {
                                Text(String.appLocalized("New Budget"))
                                    .font(.system(.body, design: .rounded).weight(.semibold))
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 12)
                            }
                            .buttonStyle(.borderedProminent)
                            .padding(.top, 6)

                            Spacer()
                            Spacer()
                        }
                        .padding(20)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            }
            .navigationBarTitle("")
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: MainBudgetModel.self) { budget in
                DetailedMainBudgetView(budget: budget)
                    .onAppear {
                        withAnimation(.easeOut.speed(2)) {
                            tabBarManager.navigationHideTab()
                        }
                    }
                    .onDisappear {
                        withAnimation(.easeOut.speed(2)) {
                            tabBarManager.navigationShowTab()
                        }
                    }
            }
            .navigationDestination(for: BudgetModel.self) { budget in
                DetailedBudgetView(budget: budget)
                    .onAppear {
                        withAnimation(.easeOut.speed(2)) {
                            tabBarManager.navigationHideTab()
                        }
                    }
                    .onDisappear {
                        withAnimation(.easeOut.speed(2)) {
                            tabBarManager.navigationShowTab()
                        }
                    }
            }
            .sheet(item: $toEdit, onDismiss: {
                toEdit = nil
            }) { budget in
                BrandNewBudgetView(overallBudgetCreated: !mainBudget.isEmpty, toEditBudget: budget)
            }
            .onAppear {
                budgetVM.load()
                budgetVM.updateDates()
            }
            .sheet(isPresented: $newBudget) {
                BrandNewBudgetView(overallBudgetCreated: !mainBudget.isEmpty)
            }
            .fullScreenCover(item: $toDelete, onDismiss: {
                toDelete = nil
            }) { budget in
                DeleteBudgetAlert(toDelete: budget)
            }
        }
    }
}

struct MainBudgetView: View {
    let budget: MainBudgetModel

    @Environment(BudgetViewModel.self) var budgetVM

    @State var toEdit: MainBudgetModel?
    @State var toDelete: MainBudgetModel?

    var totalSpent: Double {
        budgetAmount - budgetVM.leftoverOverall(budget)
    }

    var soloBudget: Bool

    var budgetAmount: Double {
        return budget.amount
    }

    var budgetType: String {
        switch budget.type {
        case 1:
            return String.appLocalized("today")
        case 2:
            return String.appLocalized("this week")
        case 3:
            return String.appLocalized("this month")
        case 4:
            return String.appLocalized("this year")
        default:
            return String.appLocalized("this week")
        }
    }

    @AppStorage("currency", store: .appGroup) var currency: String = Locale.current.currency?.identifier ?? "USD"
    var currencySymbol: String {
        return Locale.appCurrencySymbol(forCurrencyCode: currency)
    }

    var percentageOfDays: Double {
        let calendar = Calendar.current

        if budget.type == 1 {
            let components = calendar.dateComponents([.minute], from: budget.wrappedDate, to: Date.now)
            return Double(components.minute ?? 0) / 1440
        }

        let components1 = calendar.dateComponents([.day], from: budget.wrappedDate, to: budget.endDate)
        let numberOfDays = components1.day ?? 0

        let components2 = calendar.dateComponents([.day], from: budget.wrappedDate, to: Date.now)
        let numberOfDaysPast = components2.day ?? 0

        return Double(numberOfDaysPast) / Double(numberOfDays)
    }

    var targetPercent: Double {
        let calendar = Calendar.current

        let components1 = calendar.dateComponents([.day], from: budget.wrappedDate, to: budget.endDate)
        let numberOfDays = components1.day ?? 0

        let components2 = calendar.dateComponents([.day], from: budget.wrappedDate, to: Date.now)
        let numberOfDaysPast = (components2.day ?? 0) + 1

        return Double(numberOfDays - numberOfDaysPast) / Double(numberOfDays)
    }

    var triangleOffset: (x: Double, y: Double) {
        var x = 0.0
        var y = -5.0

        let radius = (width / 2) - 5

        if targetPercent > 0.5 {
            let angle = (CGFloat.pi) * (1 - targetPercent)
            y += (radius - (radius * sin(angle)))
            x += (radius * cos(angle))
        } else if targetPercent < 0.5 {
            let angle = (CGFloat.pi) * targetPercent
            y += (radius - (radius * sin(angle)))
            x -= (radius * cos(angle))
        }

        return (x, y)
    }

    var triangleRotation: Double {
        if targetPercent > 0.5 {
            return ((targetPercent - 0.5) / 0.5) * 90
        } else if targetPercent < 0.5 {
            return -((0.5 - targetPercent) / 0.5) * 90
        } else {
            return 0
        }
    }

    var difference: Double {
        return abs(budgetAmount - totalSpent)
    }

    var percentString: String {
        return "\(Int(round(100 - (totalSpent / budgetAmount) * 100)))%"
    }

    var percentString1: String {
        return "\(Int(round((totalSpent / budgetAmount) * 100)))%"
    }

    var width: CGFloat {
        if soloBudget {
            return ScreenSize.width - 90
        } else {
            return 250
        }
    }

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: 5) {
            ZStack(alignment: .bottom) {
                ZStack {
                    DonutSemicircle(percent: 1, cornerRadius: 6.5, width: soloBudget ? 35 : 25)
                        .fill(Color.SecondaryBackground)
                        .frame(width: width, height: width / 2)

                    if totalSpent / budgetAmount < 0.97 {
                        AnimatedCurvedBarGraphMainBudget(totalSpent: totalSpent, budgetTotal: budgetAmount, cornerRadius: 6.5, width: soloBudget ? 35 : 25)
                            .frame(width: width, height: width / 2)
                    }
                }
                .overlay(alignment: .top) {
                    if budget.type != 1 && totalSpent < budgetAmount && targetPercent > 0 {
                        RoundedTriangle(cornerRadius: 2)

                            .fill((targetPercent * budgetAmount) < (budgetAmount - totalSpent) ? Color.SubtitleText : Color.AlertRed)
                            .frame(width: 20, height: 10)
                            .rotationEffect(Angle(degrees: triangleRotation), anchor: .bottom)
                            .offset(x: triangleOffset.x, y: triangleOffset.y)
                    }
                }

                ArcedText(text: String(localized: "OVERALL SPENT: \(percentString1)"), radius: width / 2 + 8)
                    .font(.system(.footnote, design: .rounded).weight(.medium))
                    .foregroundStyle(Color.SubtitleText)
                    .frame(width: width, height: 10)

                VStack(spacing: -4) {
                    let internalWidth = soloBudget ? width - 90 : width - 60
                    BudgetDollarView(amount: difference, red: totalSpent >= budgetAmount, scale: 3, size: internalWidth)
                        .frame(width: internalWidth)

                    Text("\(budgetAmount >= totalSpent ? String.appLocalized("left") : String.appLocalized("over")) \(budgetType)")
                        .font(.system(.subheadline, design: .rounded).weight(.medium))
//                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.SubtitleText)
                }
            }

            HStack {
                if totalSpent < 1000 && budgetAmount < 1000 {
                    Text(totalSpent, format: .number.precision(.fractionLength(2)))
                        .frame(width: 60, alignment: .leading)
                    Spacer()
                    Text(budgetAmount, format: .number.precision(.fractionLength(2)))
                        .frame(width: 60, alignment: .trailing)
                } else {
                    Text("\(Int(round(totalSpent)))")
                        .frame(width: 60, alignment: .leading)
                    Spacer()
                    Text("\(Int(round(budgetAmount)))")
                        .frame(width: 60, alignment: .trailing)
                }
            }
            .font(.system(.caption2, design: .rounded).weight(.medium))
//            .font(.system(size: 10, weight: .medium, design: .rounded))
            .frame(width: width)
            .foregroundStyle(Color.SubtitleText)
        }
        .padding(.bottom)
        .frame(width: width + 30, height: soloBudget ? 230 : 200, alignment: .bottom)
        .glassCard(in: RoundedRectangle(cornerRadius: GlassRadius.card, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: GlassRadius.card))
        .contextMenu {
            Button {
                toEdit = budget

            } label: {
                Label(String.appLocalized("Edit"), systemImage: "pencil")
            }
            Button {
                toDelete = budget

            } label: {
                Label(String.appLocalized("Delete"), systemImage: "xmark.bin")
            }
        }
        .sheet(item: $toEdit, onDismiss: {
            toEdit = nil
        }) { budget in
            BrandNewBudgetView(overallBudgetCreated: true, toEditMainBudget: budget)
        }
        .fullScreenCover(item: $toDelete, onDismiss: {
            toDelete = nil
        }) { budget in
            DeleteMainBudgetAlert(toDelete: budget)
        }
    }

    init(budget: MainBudgetModel, solo: Bool) {
        self.budget = budget
        soloBudget = solo
    }
}

