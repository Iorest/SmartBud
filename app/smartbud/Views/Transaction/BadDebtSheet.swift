//
//  BadDebtSheet.swift
//  smartbud
//
//  Gives up on a claim nobody paid back. The amount is not entered — it is the
//  claim's, and the claim keeps its own row — and there is no account to pick,
//  because nothing moves: only the spend figure changes. The one thing the
//  sheet asks for is *why*, which is what the loss row stores
//  (`docs/accounting-conventions.md` §2).
//

import SwiftData
import SwiftUI

struct BadDebtTarget: Identifiable {
    let claim: TransactionModel
    var id: UUID { claim.id }
}

struct BadDebtSheet: View {
    @Environment(TransactionViewModel.self) private var transactionVM
    @Environment(InsightsViewModel.self) private var insightsVM
    @Environment(\.dismiss) private var dismiss

    @AppStorage("showCents", store: .appGroup) private var showCents: Bool = true

    let claim: TransactionModel

    @State private var reason: BadDebtPolicy.Reason = .unreachable
    @State private var refusal: BadDebtPolicy.Failure?
    @State private var saveFailed = false

    private var amountText: String {
        Money.format(claim.wrappedBaseAmount, currencyCode: AppBaseCurrency.code,
                     showsCents: showCents, locale: .appLocale)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent(String.appLocalized("Amount"), value: amountText)
                    LabeledContent(String.appLocalized("Claimed On"),
                                   value: claim.wrappedDate.formatted(date: .abbreviated,
                                                                     time: .omitted))
                    Picker(String.appLocalized("Reason"), selection: $reason) {
                        ForEach(BadDebtPolicy.Reason.allCases, id: \.self) { reason in
                            Text(reason.label).tag(reason)
                        }
                    }
                } footer: {
                    Text(String.appLocalized(
                        "The loss is counted as spending from today. The original expense and its history stay as they are."))
                }

                if let refusalMessage {
                    Section {
                        Text(refusalMessage)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(String.appLocalized("Write Off Claim"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String.appLocalized("Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String.appLocalized("Write Off")) { save() }
                }
            }
        }
    }

    private var refusalMessage: String? {
        if saveFailed { return String.appLocalized("Couldn't save the write-off.") }
        switch refusal {
        case .none:
            return nil
        case .notAClaim:
            return String.appLocalized("Only an expense waiting to be paid back can be written off.")
        case .alreadySettled:
            return String.appLocalized("That money already came back.")
        case .alreadyWrittenOff:
            return String.appLocalized("This claim was already written off.")
        case .tooRecent(let daysLeft):
            return String.appFormatted("A claim can be written off after 90 days. %lld days to go.",
                                       daysLeft)
        case .nonPositiveAmount:
            return String.appLocalized("The claim has no amount to write off.")
        }
    }

    private func save() {
        saveFailed = false
        refusal = nil
        switch transactionVM.writeOff(claim, reason: reason) {
        case .success:
            insightsVM.refreshAll()
            dismiss()
        case .refused(let failure):
            refusal = failure
        case .saveFailed:
            saveFailed = true
        }
    }
}

extension BadDebtPolicy.Reason {
    /// Wording for the picker and the row badge. Lives here, not in the
    /// policy, so the Foundation-only file stays free of the localisation
    /// helper (and of UIKit).
    var label: String {
        switch self {
        case .unreachable:
            return String.appLocalized("Cannot Reach Payer")
        case .rejected:
            return String.appLocalized("Claim Rejected")
        case .companyClosed:
            return String.appLocalized("Company Closed")
        case .other:
            return String.appLocalized("Other")
        }
    }
}
