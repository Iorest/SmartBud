import CoreHaptics
import Foundation
import SwiftUI
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

struct CategoryListView: View {
    @Binding var income: Bool
    var mode: CategoryViewMode
    /// When set (transaction mode), a row tap picks the category instead of
    /// opening the edit sheet. Editing stays available via swipe actions.
    var onSelect: ((CategoryModel) -> Void)?

    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var systemColorScheme
    @Environment(CategoryViewModel.self) var categoryVM

    @AppStorage("categorySuggestions", store: .appGroup) var showSuggestions: Bool = true

    var categories: [CategoryModel] {
        income ? categoryVM.incomeCategories : categoryVM.expenseCategories
    }

    @State var isEditing = false

    var allCategories: [CategoryModel] {
        categoryVM.incomeCategories + categoryVM.expenseCategories
    }

    // delete mode
    @State var deleteMode = false
    @State var toDelete: CategoryModel?
    // edit mode
    @State var toEdit: CategoryModel?

    // toasts
    @Binding var showToast: Bool
    @Binding var toastTitle: String
    @Binding var toastImage: String
    @Binding var positive: Bool

    var sectionHeader: LocalizedStringKey {
        if income {
            return "INCOME CATEGORIES"
        } else {
            return "EXPENSE CATEGORIES"
        }
    }

    func moveItem(at sets: IndexSet, destination: Int) {
        categoryVM.reorder(from: sets, to: destination, income: income)
    }

    init(income: Binding<Bool>, mode: CategoryViewMode, onSelect: ((CategoryModel) -> Void)? = nil,
         showToast: Binding<Bool>, toastTitle: Binding<String>, toastImage: Binding<String>, positive: Binding<Bool>) {
        _income = income
        _showToast = showToast
        _toastTitle = toastTitle
        _toastImage = toastImage
        _positive = positive
        self.mode = mode
        self.onSelect = onSelect
    }
}
