import Foundation
import SwiftUI
import SwiftData

struct DetailedBudgetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(BudgetViewModel.self) private var budgetVM
    let budget: BudgetModel

    @State private var toDelete: BudgetModel?

    @State var newTransaction = false

    @State private var toEdit: BudgetModel?

    var body: some View {
        VStack(spacing: 15) {
            HStack {
                Button {
                    dismiss()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.SubtitleText)

                        Text(String.appLocalized("Back"))
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Color.SubtitleText)
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 8)
                    .fixedSize(horizontal: false, vertical: /*@START_MENU_TOKEN@*/true/*@END_MENU_TOKEN@*/)
                    .background(Color.SecondaryBackground, in: Capsule())
                }

                Spacer()

                DetailedBudgetViewTopBarButton(imageName: "plus", color: Color("110"), label: String
                    .appLocalized("Add transaction")) {
                    newTransaction = true
                }

                DetailedBudgetViewTopBarButton(imageName: "pencil", color: Theme.Brand.edit, label: String
                    .appLocalized("Edit budget")) {
                    toEdit = budget
                }

                DetailedBudgetViewTopBarButton(imageName: "trash.fill", color: Color.AlertRed, label: String
                    .appLocalized("Delete budget")) {
                    toDelete = budget
                }
            }
            .padding(.horizontal, 20)

            BudgetTimeView(
                amount: budget.amount,
                type: budget.type,
                budgetStart: budget.wrappedDate,
                endDate: budget.endDate,
                category: budget.category,
                title: budget.wrappedName,
                emoji: budget.wrappedEmoji
            )
        }
        .padding(.vertical, 15)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .hiddenNavigationBackButton()
        .hiddenNavigationBar()
        .appBackground()
        .sheet(item: $toEdit) { budget in
            BrandNewBudgetView(overallBudgetCreated: false, toEditBudget: budget)
        }
        .fullScreenPresentation(isPresented: $newTransaction) {
            TransactionView(category: budget.category)
        }
        .alert(
            String(format: String.appLocalized("Delete the '%@' budget?"),
                   toDelete?.category?.wrappedName ?? ""),
            isPresented: Binding(get: { toDelete != nil },
                                 set: { if !$0 { toDelete = nil } }),
            presenting: toDelete
        ) { budget in
            Button(String.appLocalized("Delete"), role: .destructive) {
                withAnimation { budgetVM.delete(budget) }
                dismiss()
            }
            Button(String.appLocalized("Cancel"), role: .cancel) { toDelete = nil }
        } message: { _ in
            Text(String.appLocalized("This action cannot be undone."))
        }
    }
}

struct DetailedMainBudgetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(BudgetViewModel.self) private var budgetVM
    let budget: MainBudgetModel

    @State private var toDelete: MainBudgetModel?

    @State private var toEdit: MainBudgetModel?

    var body: some View {
        VStack(spacing: 15) {
            HStack {
                Button {
                    dismiss()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.SubtitleText)

                        Text(String.appLocalized("Back"))
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Color.SubtitleText)
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 8)
                    .fixedSize(horizontal: false, vertical: /*@START_MENU_TOKEN@*/true/*@END_MENU_TOKEN@*/)
                    .background(Color.SecondaryBackground, in: Capsule())
                }

                Spacer()

                DetailedBudgetViewTopBarButton(imageName: "pencil", color: Theme.Brand.edit, label: String
                    .appLocalized("Edit budget")) {
                    toEdit = budget
                }

                DetailedBudgetViewTopBarButton(imageName: "trash.fill", color: Color.AlertRed, label: String
                    .appLocalized("Delete budget")) {
                    toDelete = budget
                }
            }
            .padding(.horizontal, 20)

            BudgetTimeView(
                amount: budget.amount,
                type: budget.type,
                budgetStart: budget.wrappedDate,
                endDate: budget.endDate,
                category: nil,
                title: String.appLocalized("Overall Budget"),
                emoji: nil
            )
        }
        .padding(.vertical, 15)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .hiddenNavigationBackButton()
        .hiddenNavigationBar()
        .appBackground()
        .fullScreenPresentation(item: $toEdit) { budget in
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
                dismiss()
            }
            Button(String.appLocalized("Cancel"), role: .cancel) { toDelete = nil }
        } message: { _ in
            Text(String.appLocalized("This action cannot be undone."))
        }
    }
}
