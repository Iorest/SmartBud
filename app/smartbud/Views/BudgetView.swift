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
    @Query private var fetchedCategories: [CategoryModel]
    @Query private var fetchedBudgets: [BudgetModel]
    @Query private var fetchedMainBudget: [MainBudgetModel]
    @Environment(BookState.self) private var bookState

    // A query cannot read the device-local book id; scope after fetching so
    // the empty state and the list only ever describe the active ledger.
    private var categories: [CategoryModel] {
        BookScope.scoped(fetchedCategories, \.bookID, selected: bookState.currentID)
    }
    private var budgets: [BudgetModel] {
        BookScope.scoped(fetchedBudgets, \.bookID, selected: bookState.currentID)
    }
    private var mainBudget: [MainBudgetModel] {
        BookScope.scoped(fetchedMainBudget, \.bookID, selected: bookState.currentID)
    }

    @State private var showNewBudget = false

    var body: some View {
        if categories.isEmpty && budgets.isEmpty && mainBudget.isEmpty {
            SBEmptyState(
                systemImage: "chart.pie",
                title: String.appLocalized("Budget Your Finances"),
                message: String.appLocalized("Link budgets to categories and set appropriate expenditure goals"),
                actionTitle: String.appLocalized("新建预算"),
                actionIdentifier: AccessibilityID.budgetAddButton,
                action: { showNewBudget = true }
            )
            .sheet(isPresented: $showNewBudget) {
                BrandNewBudgetView(overallBudgetCreated: false)
            }
        } else {
            ActualBudgetView()
        }
    }
}

struct ActualBudgetView: View {

    @Query(sort: [SortDescriptor(\BudgetModel.dateCreated)]) private var fetchedBudgets: [BudgetModel]
    @Query private var fetchedMainBudget: [MainBudgetModel]
    @Environment(BookState.self) private var bookState
    @Environment(BudgetViewModel.self) var budgetVM

    private var budgets: [BudgetModel] {
        BookScope.scoped(fetchedBudgets, \.bookID, selected: bookState.currentID)
    }
    private var mainBudget: [MainBudgetModel] {
        BookScope.scoped(fetchedMainBudget, \.bookID, selected: bookState.currentID)
    }

    @State var newBudget = false

    @State private var toDelete: BudgetModel?
    @State private var toEdit: BudgetModel?

    let layout = [
        GridItem(.flexible(), spacing: 15),
        GridItem(.flexible(), spacing: 15)
    ]

    @AppStorage("budgetViewStyle", store: .appGroup) var budgetRows: Bool = false

    var body: some View {
        NavigationStack {
            ZStack {
                VStack(spacing: 0) {
                    if !budgets.isEmpty || !mainBudget.isEmpty {
                        ScrollView(showsIndicators: false) {
                            VStack {
                                Color.clear.frame(height: 8)
                                if let first = mainBudget.first {
                                    NavigationLink(value: first) {
                                        MainBudgetView(budget: first)
                                            .padding(.horizontal, 25)
                                            .padding(.bottom, 15)
                                    }
                                }

                                if budgetRows {
                                    VStack(spacing: 10) {
                                        ForEach(budgets, id: \.id) { budget in
                                            NavigationLink(value: budget) {
                                                SingleBudgetView(
                                                    budget: budget,
                                                    toDelete: $toDelete,
                                                    toEdit: $toEdit,
                                                    budgetRows: budgetRows
                                                )
                                            }
                                        }
                                    }

                                } else {
                                    LazyVGrid(columns: layout, spacing: 15) {
                                        ForEach(budgets, id: \.id) { budget in
                                            NavigationLink(value: budget) {
                                                SingleBudgetView(
                                                    budget: budget,
                                                    toDelete: $toDelete,
                                                    toEdit: $toEdit,
                                                    budgetRows: budgetRows
                                                )
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
                        SBEmptyState(
                            systemImage: "chart.pie",
                            title: String.appLocalized("No Budgets Found"),
                            message: String.appLocalized("Add your first budget today!"),
                            actionTitle: String.appLocalized("New Budget"),
                            action: { newBudget = true }
                        )
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            }
            .navigationTitle(String.appLocalized("Budget"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        newBudget = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel(String.appLocalized("New Budget"))
                    .accessibilityHint(Text(String.appLocalized("Create a new budget")))
                    .accessibilityIdentifier(AccessibilityID.budgetAddButton)
                }
            }
            .navigationDestination(for: MainBudgetModel.self) { budget in
                DetailedMainBudgetView(budget: budget)
            }
            .navigationDestination(for: BudgetModel.self) { budget in
                DetailedBudgetView(budget: budget)
            }
            .sheet(item: $toEdit) { budget in
                BrandNewBudgetView(overallBudgetCreated: !mainBudget.isEmpty, toEditBudget: budget)
            }
            .onAppear {
                budgetVM.load()
                budgetVM.updateDates()
            }
            .sheet(isPresented: $newBudget) {
                BrandNewBudgetView(overallBudgetCreated: !mainBudget.isEmpty)
            }
            .alert(
                String.appFormatted("Delete the '%@' budget?",
                       toDelete?.category?.wrappedName ?? ""),
                isPresented: Binding(get: { toDelete != nil },
                                     set: { if !$0 { toDelete = nil } }),
                    presenting: toDelete
            ) { budget in
                Button(String.appLocalized("Delete"), role: .destructive) {
                    withAnimation { budgetVM.delete(budget) }
                }
                Button(String.appLocalized("Cancel"), role: .cancel) { toDelete = nil }
            } message: { _ in
                Text(String.appLocalized("This action cannot be undone."))
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

    var budgetAmount: Double {
        return budget.amount
    }

    var budgetType: String {
        String.appLocalized(BudgetPeriod.labelKey(for: budget.type))
    }

    @AppStorage("currency", store: .appGroup) var currency: String = Locale.current.currency?.identifier ?? "USD"
    var currencySymbol: String {
        return Locale.appCurrencySymbol(forCurrencyCode: currency)
    }

    var difference: Double {
        return abs(budgetAmount - totalSpent)
    }

    var percentString: String {
        return "\(Int(round(100 - Money.spendFraction(totalSpent, of: budgetAmount) * 100)))%"
    }

    var percentString1: String {
        return "\(Int(round(Money.spendFraction(totalSpent, of: budgetAmount) * 100)))%"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: SBSpace.small) {
            HStack(alignment: .firstTextBaseline, spacing: SBSpace.extraSmall) {
                Label(String.appLocalized("Total Budget"), systemImage: "chart.pie.fill")
                    .font(.headline)
                    .foregroundStyle(Color.PrimaryText)

                Spacer(minLength: SBSpace.extraSmall)

                Text(percentString1)
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(totalSpent >= budgetAmount ? Color.AlertRed : Color.SubtitleText)
            }

            HStack(alignment: .firstTextBaseline, spacing: SBSpace.xxs) {
                Text(String.appLocalized(budgetAmount >= totalSpent ? "Left" : "Over"))
                    .font(.subheadline)
                    .foregroundStyle(Color.SubtitleText)

                Text(difference, format: .currency(code: currency))
                    .font(.largeTitle.weight(.semibold).monospacedDigit())
                    .foregroundStyle(totalSpent >= budgetAmount ? Color.AlertRed : Color.PrimaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }

            ProgressView(value: min(max(totalSpent / max(budgetAmount, 1), 0), 1))
                .tint(totalSpent >= budgetAmount ? Color.AlertRed : Color.accentColor)
                .accessibilityLabel(String.appLocalized("Spent"))
                .accessibilityValue(percentString1)

            HStack {
                Text(totalSpent, format: .currency(code: currency))
                Spacer(minLength: SBSpace.extraSmall)
                Text(budgetAmount, format: .currency(code: currency))
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(Color.SubtitleText)

            Text(budgetType)
                .font(.caption)
                .foregroundStyle(Color.SubtitleText)
        }
        .padding(SBSpace.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .systemCard(in: RoundedRectangle(cornerRadius: SBRadius.card, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: SBRadius.card))
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
        .sheet(item: $toEdit) { budget in
            BrandNewBudgetView(overallBudgetCreated: true, toEditMainBudget: budget)
        }
        .alert(
            String.appLocalized("Delete your overall budget?"),
            isPresented: Binding(get: { toDelete != nil },
                                 set: { if !$0 { toDelete = nil } }),
            presenting: toDelete
        ) { budget in
            Button(String.appLocalized("Delete"), role: .destructive) {
                withAnimation { budgetVM.deleteMain(budget) }
            }
            Button(String.appLocalized("Cancel"), role: .cancel) { toDelete = nil }
        } message: { _ in
            Text(String.appLocalized("This action cannot be undone."))
        }
    }

    init(budget: MainBudgetModel) {
        self.budget = budget
    }
}
