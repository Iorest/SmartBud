//
//  PendingReimbursementSheet.swift
//  smartbud
//
//  Every expense still waiting to be paid back. Reached from the card on the
//  insights screen; swiping a row records that the money came back.
//

import SwiftUI
import SwiftData

/// Every expense still waiting to be paid back, with a one-swipe way to
/// settle each one. Reached from the card on the insights screen.
struct PendingReimbursementSheet: View {
    @Environment(InsightsViewModel.self) private var insightsVM
    @Environment(TransactionViewModel.self) private var transactionVM
    @Environment(\.dismiss) private var dismiss

    @AppStorage("currency", store: .appGroup) private var currency: String =
        Locale.current.currency?.identifier ?? "USD"
    @AppStorage("showCents", store: .appGroup) private var showCents: Bool = true

    var body: some View {
        NavigationStack {
            List {
                if insightsVM.pendingReimbursements.isEmpty {
                    SBEmptyState(
                        systemImage: "checkmark.circle",
                        title: String.appLocalized("Nothing to claim"),
                        message: String.appLocalized(
                            "Expenses you mark as reimbursable show up here until they are paid back.")
                    )
                    .listRowSeparator(.hidden)
                } else {
                    Section {
                        ForEach(insightsVM.pendingReimbursements) { transaction in
                            row(transaction)
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button {
                                        transactionVM.setReimbursed(true, for: transaction)
                                        insightsVM.refreshAll()
                                    } label: {
                                        Label(String.appLocalized("Reimbursed"),
                                              systemImage: "checkmark.circle")
                                    }
                                    .tint(Color.IncomeGreen)
                                }
                        }
                    } footer: {
                        Text(String.appLocalized(
                            "Swipe a row to record that the money came back."))
                    }
                }
            }
            .navigationTitle(String.appLocalized("Pending Reimbursement"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String.appLocalized("Done")) { dismiss() }
                }
            }
        }
        .onAppear { insightsVM.refreshAll() }
    }

    private func row(_ transaction: TransactionModel) -> some View {
        HStack(spacing: SBSpace.small) {
            EmojiLogView(emoji: transaction.category?.wrappedEmoji ?? "",
                         colour: transaction.category?.wrappedColour ?? "#FFFFFF",
                         future: false)
                .fixedSize(horizontal: true, vertical: true)

            VStack(alignment: .leading, spacing: 2) {
                Text(transaction.wrappedNote.isEmpty
                     ? transaction.wrappedCategoryName
                     : transaction.wrappedNote)
                    .font(.body)
                    .lineLimit(2)
                Text(transaction.wrappedDate.formatted(
                    Date.FormatStyle(locale: .appLocale).year().month().day()))
                    .font(.caption)
                    .foregroundStyle(Color.SubtitleText)
            }

            Spacer(minLength: SBSpace.extraSmall)

            Text(Money.format(transaction.wrappedAmount,
                              currencyCode: transaction.account?.resolvedCurrencyCode ?? currency,
                              showsCents: showCents, locale: .appLocale))
                .font(.callout.weight(.medium).monospacedDigit())
        }
        .padding(.vertical, 2)
    }
}
