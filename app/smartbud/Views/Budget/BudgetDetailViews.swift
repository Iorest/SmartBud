import Foundation
import SwiftUI
import SwiftData

struct DetailedBudgetView: View {
    @Environment(\.dismiss) private var dismiss
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

                DetailedBudgetViewTopBarButton(imageName: "plus", color: Color("110"), label: String.appLocalized("Add transaction")) {
                    newTransaction = true
                }

                DetailedBudgetViewTopBarButton(imageName: "pencil", color: Theme.Brand.edit, label: String.appLocalized("Edit budget")) {
                    toEdit = budget
                }

                DetailedBudgetViewTopBarButton(imageName: "trash.fill", color: Color.AlertRed, label: String.appLocalized("Delete budget")) {
                    toDelete = budget
                }
            }
            .padding(.horizontal, 20)

            TimeBudgetView(budget: budget)
        }
        .padding(.vertical, 15)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .hiddenNavigationBackButton()
        .hiddenNavigationBar()
        .appBackground()
        .sheet(item: $toEdit, onDismiss: {
            toEdit = nil
        }) { budget in
            BrandNewBudgetView(overallBudgetCreated: false, toEditBudget: budget)
        }
        .fullScreenPresentation(isPresented: $newTransaction) {
            TransactionView(category: budget.category)
        }
        .fullScreenPresentation(item: $toDelete, onDismiss: {
            toDelete = nil
        }) { budget in
            DeleteBudgetAlert(toDelete: budget) {
                dismiss()
            }
        }
    }
}

struct DetailedMainBudgetView: View {
    @Environment(\.dismiss) private var dismiss
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

                DetailedBudgetViewTopBarButton(imageName: "pencil", color: Theme.Brand.edit, label: String.appLocalized("Edit budget")) {
                    toEdit = budget
                }

                DetailedBudgetViewTopBarButton(imageName: "trash.fill", color: Color.AlertRed, label: String.appLocalized("Delete budget")) {
                    toDelete = budget
                }
            }
            .padding(.horizontal, 20)

            TimeMainBudgetView(budget: budget)
        }
        .padding(.vertical, 15)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .hiddenNavigationBackButton()
        .hiddenNavigationBar()
        .appBackground()
        .fullScreenPresentation(item: $toEdit, onDismiss: {
            toEdit = nil
        }) { budget in
            BrandNewBudgetView(overallBudgetCreated: true, toEditMainBudget: budget)
        }
        .fullScreenPresentation(item: $toDelete, onDismiss: {
            toDelete = nil
        }) { budget in
            DeleteMainBudgetAlert(toDelete: budget) {
                dismiss()
            }
        }
    }
}

