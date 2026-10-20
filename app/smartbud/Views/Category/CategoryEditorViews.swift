//
//  CategoryEditorViews.swift
//  smartbud
//
//  One editor for both creating and editing a category. The two screens used
//  to be separate 300-line types that had to be kept in sync by hand; they
//  now share this implementation and differ only in the header and in what
//  the save button does.
//

import SwiftUI
import SwiftData

// MARK: - Entry points

struct NewCategoryAlert: View {
    @Binding var income: Bool
    let bottomSpacers: Bool
    var budgetMode: Bool = false

    var body: some View {
        CategoryEditor(income: $income, editing: nil, budgetMode: budgetMode,
                       bottomSpacers: bottomSpacers)
    }
}

struct EditCategoryAlert: View {
    let toEdit: CategoryModel
    @Binding var showRootToast: Bool
    @Binding var rootToastTitle: String
    @Binding var rootToastImage: String
    @Binding var positive: Bool
    let bottomSpacers: Bool

    var body: some View {
        CategoryEditor(income: .constant(toEdit.income), editing: toEdit,
                       budgetMode: false, bottomSpacers: bottomSpacers) { title in
            rootToastTitle = title
            rootToastImage = "checkmark.circle.fill"
            positive = true
            showRootToast = true
        }
    }
}

// MARK: - Shared editor
