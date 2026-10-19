import Foundation
import SwiftUI
import SwiftData

struct DetailedBudgetView: View {
    @Environment(\.dismiss) var dismiss
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
                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                            .foregroundStyle(Color.SubtitleText)

                        Text(String.appLocalized("Back"))
                            .font(.system(.body, design: .rounded).weight(.semibold))
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

                DetailedBudgetViewTopBarButton(imageName: "pencil", color: Color("6"), label: String.appLocalized("Edit budget")) {
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
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .appBackground()
        .sheet(item: $toEdit, onDismiss: {
            toEdit = nil
        }) { budget in
            BrandNewBudgetView(overallBudgetCreated: false, toEditBudget: budget)
        }
        .fullScreenCover(isPresented: $newTransaction) {
            TransactionView(category: budget.category)
        }
        .fullScreenCover(item: $toDelete, onDismiss: {
            toDelete = nil
        }) { budget in
            DeleteBudgetAlert(toDelete: budget)
        }
    }
}

struct DetailedMainBudgetView: View {
    @Environment(\.dismiss) var dismiss
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
                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                            .foregroundStyle(Color.SubtitleText)

                        Text(String.appLocalized("Back"))
                            .font(.system(.body, design: .rounded).weight(.semibold))
                            .foregroundStyle(Color.SubtitleText)
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 8)
                    .fixedSize(horizontal: false, vertical: /*@START_MENU_TOKEN@*/true/*@END_MENU_TOKEN@*/)
//                    .frame(height: 30, alignment: .center)
                    .background(Color.SecondaryBackground, in: Capsule())
                }

                Spacer()

                DetailedBudgetViewTopBarButton(imageName: "pencil", color: Color("6"), label: String.appLocalized("Edit budget")) {
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
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .appBackground()
        .fullScreenCover(item: $toEdit, onDismiss: {
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
}

