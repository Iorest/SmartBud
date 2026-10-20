//
//  LogTransactionViews+Alerts.swift
//  smartbud
//
import Foundation
import SwiftData
import SwiftUI

struct DeleteTransactionAlert: View {
    @Environment(TransactionViewModel.self) var transactionVM
    @Environment(\.dismiss) var dismiss
    @Environment(OverallTransactionManager.self) var transactionManager

    var stopRecurring: Bool {
        if let unwrapped = transactionManager.toDelete {
            return transactionManager.future && unwrapped.wrappedDate < Date.now && unwrapped.recurringType > 0
        } else {
            return false
        }
    }

    @Environment(\.colorScheme) var systemColorScheme

    @AppStorage("bottomEdge", store: .appGroup) var bottomEdge: Double = 15

    @State private var offset: CGFloat = 0

    var body: some View {
        if let unwrappedToDelete = transactionManager.toDelete {
            VStack(alignment: .leading, spacing: 1.5) {
                Text(stopRecurring ? String.appLocalized("Stop Recurring?") : String
                    .appFormatted("Delete '%@'?", unwrappedToDelete.wrappedNote))
                    .font(.title2.weight(.medium))

                    .foregroundStyle(Color.PrimaryText)
                    .accessibilityLabel(String.appFormatted("Delete %@ transaction confirmation. "
                         + "You can undo right after deleting.", unwrappedToDelete.wrappedNote))

                Text(String
                    .appLocalized(
            stopRecurring
                ? "The transaction will no longer be automatically logged."
                : "You can undo right after deleting."
        )
    )
                    .font(.title3.weight(.medium))

                    .foregroundStyle(Color.SubtitleText)
                    .padding(.bottom, 25)
                    .accessibilityHidden(true)

                Button {
                    transactionManager.showPopup = false

                    if stopRecurring {
                        withAnimation(.easeInOut(duration: 0.5)) {
                            transactionVM.stopRecurring(unwrappedToDelete)
                        }
                    } else {
                        withAnimation(.easeInOut(duration: 0.5)) {
                            transactionVM.stageDelete(unwrappedToDelete)
                        }
                    }
                } label: {
                    DeleteButton(text: String.appLocalized(stopRecurring ? "Confirm" : "Delete"), red: true)
                }
                .padding(.bottom, 8)

                Button {
                    transactionManager.showPopup = false
                } label: {
                    DeleteButton(text: String.appLocalized("Cancel"), red: false)
                }
            }
            .padding(13)
            .systemCard(in: RoundedRectangle(cornerRadius: SBRadius.card, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: SBRadius.card)
                .stroke(systemColorScheme == .dark ? Color.gray.opacity(0.1) : Color.clear, lineWidth: 1.3))
            .padding(.horizontal, 17)
            .padding(.bottom, bottomEdge == 0 ? 13 : bottomEdge)
        }
    }
}
