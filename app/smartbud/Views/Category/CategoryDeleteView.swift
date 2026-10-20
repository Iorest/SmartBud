import CoreHaptics
import Foundation
import SwiftUI
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

struct DeleteCategoryAlert: View {
    @Environment(CategoryViewModel.self) var categoryVM
    let toDelete: CategoryModel
    @Binding var deleted: Bool

    var body: some View {
        SBDeleteSheet(
            title: String.appFormatted("Delete '%@'?", toDelete.wrappedName),
            message: String(
                format: String.appLocalized(
                    "This action cannot be undone. %@ transactions are kept and become uncategorized, "
                        + "and this category's budget is deleted."),
                toDelete.wrappedName
            )
        ) {
            deleted = true
            withAnimation { categoryVM.delete(toDelete) }
        }
    }
}
