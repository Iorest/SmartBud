import Foundation
import SwiftUI
import SwiftData

struct DeleteBudgetAlert: View {
    @Environment(BudgetViewModel.self) var budgetVM
    let toDelete: BudgetModel
    var onDeleted: (() -> Void)?

    var body: some View {
        SBDeleteSheet(
            title: String(format: String.appLocalized("Delete the '%@' budget?"),
                          toDelete.category?.wrappedName ?? "")
        ) {
            withAnimation { budgetVM.delete(toDelete) }
            onDeleted?()
        }
    }
}

struct DeleteMainBudgetAlert: View {
    @Environment(BudgetViewModel.self) var budgetVM
    let toDelete: MainBudgetModel
    var onDeleted: (() -> Void)?

    var body: some View {
        SBDeleteSheet(title: String.appLocalized("Delete your overall budget?")) {
            withAnimation { budgetVM.deleteMain(toDelete) }
            onDeleted?()
        }
    }
}
