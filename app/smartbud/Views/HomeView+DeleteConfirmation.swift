//
//  HomeView+DeleteConfirmation.swift
//  smartbud
//
//  Copy and presentation state for the transaction delete dialog. Lives in
//  its own file so `HomeView` stays under the file-length limit.
//

import SwiftUI

extension HomeView {
    /// Deleting a past occurrence of a recurring transaction asks whether the
    /// series should stop; the wording comes from the shared copy keys.
    var stopRecurringDelete: Bool {
        guard let transaction = transactionManager.toDelete else { return false }
        return transactionManager.future
            && transaction.wrappedDate < Date.now
            && transaction.recurringType > 0
    }

    var deleteDialogTitle: String {
        if stopRecurringDelete { return String.appLocalized("Stop Recurring?") }
        return String.appFormatted("Delete '%@'?", transactionManager.toDelete?.wrappedNote ?? "")
    }

    var deleteDialogMessage: String {
        String.appLocalized(stopRecurringDelete
            ? "The transaction will no longer be automatically logged."
            : "You can undo right after deleting.")
    }

    var deleteDialogPresented: Binding<Bool> {
        Binding(
            get: { transactionManager.showPopup },
            set: { newValue in
                transactionManager.showPopup = newValue
                if !newValue { transactionManager.toDelete = nil }
            }
        )
    }
}
