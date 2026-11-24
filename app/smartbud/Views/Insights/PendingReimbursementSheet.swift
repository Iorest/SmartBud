//
//  PendingReimbursementSheet.swift
//  smartbud
//
//  Every expense still waiting to be paid back. Reached from the card on the
//  insights screen; a row can be settled in full with one swipe or in
//  instalments through the sheet. The amount shown is what is still owed,
//  which is also the part counted as the user's own spending.
//

import SwiftUI
import SwiftData

/// Wrapper so a claim can drive `.sheet(item:)` without making the model
/// itself Identifiable.
struct RepaymentTarget: Identifiable {
    let claim: TransactionModel
    var id: UUID { claim.id }
}

/// Every expense still waiting to be paid back. Reached from the card on the
/// insights screen.
struct PendingReimbursementSheet: View {
    @Environment(InsightsViewModel.self) private var insightsVM
    @Environment(TransactionViewModel.self) private var transactionVM
    @Environment(\.dismiss) private var dismiss

    @AppStorage("currency", store: .appGroup) private var currency: String =
        Locale.current.currency?.identifier ?? "USD"
    @AppStorage("showCents", store: .appGroup) private var showCents: Bool = true
    /// The claim being written off, if the sheet is open.
    @State private var writeOffTarget: BadDebtTarget?
    /// The claim receiving one instalment, if the amount sheet is open.
    @State private var repaymentTarget: RepaymentTarget?

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

                                    // One swipe for the common full payment;
                                    // the sheet defaults to the same amount
                                    // but lets the user pay only part of it.
                                    Button {
                                        repaymentTarget = RepaymentTarget(claim: transaction)
                                    } label: {
                                        Label(String.appLocalized("Repay Part…"),
                                              systemImage: "banknote")
                                    }
                                    .tint(Color.orange)

                                    // A claim nobody paid back becomes a real
                                    // expense instead of waiting forever. The
                                    // action only appears after the waiting
                                    // period (`BadDebtPolicy.thresholdDays`).
                                    if transactionVM.canWriteOff(transaction) {
                                        Button {
                                            writeOffTarget = BadDebtTarget(claim: transaction)
                                        } label: {
                                            Label(String.appLocalized("Write Off"),
                                                  systemImage: "xmark.bin")
                                        }
                                        .tint(Color.AlertRed)
                                    }
                                }
                        }
                    } footer: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(String.appLocalized(
                                "Swipe a row to record that the money came back."))
                            Text(String.appLocalized(
                                "Money nobody pays back can be written off after 90 days, so it stops being invisible."))
                        }
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
        .sheet(item: $writeOffTarget) { target in
            BadDebtSheet(claim: target.claim)
        }
        .sheet(item: $repaymentTarget) { target in
            ReimbursementSheet(claim: target.claim)
        }
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
                if transaction.reimbursedAmount > 0 {
                    Text(String.appFormatted(
                        "%@ of %@",
                        Money.format(transaction.unreimbursedAmount,
                                     currencyCode: transaction.account?.resolvedCurrencyCode ?? currency,
                                     showsCents: showCents, locale: .appLocale),
                        Money.format(transaction.amount,
                                     currencyCode: transaction.account?.resolvedCurrencyCode ?? currency,
                                     showsCents: showCents, locale: .appLocale)))
                        .font(.caption)
                        .foregroundStyle(Color.SubtitleText)
                }
            }

            Spacer(minLength: SBSpace.extraSmall)

            Text(Money.format(transaction.unreimbursedAmount,
                              currencyCode: transaction.account?.resolvedCurrencyCode ?? currency,
                              showsCents: showCents, locale: .appLocale))
                .font(.callout.weight(.medium).monospacedDigit())
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .onTapGesture { repaymentTarget = RepaymentTarget(claim: transaction) }
        .accessibilityElement(children: .combine)
        .accessibilityHint(String.appLocalized("Opens the repayment sheet."))
    }
}

/// One instalment of a claim. The default is the whole balance, since paying
/// the claim off is the common case; the balance and the refused amount are
/// always shown in the claim's own currency.
struct ReimbursementSheet: View {
    @Environment(TransactionViewModel.self) private var transactionVM
    @Environment(InsightsViewModel.self) private var insightsVM
    @Environment(\.dismiss) private var dismiss

    @AppStorage("showCents", store: .appGroup) private var showCents: Bool = true

    let claim: TransactionModel

    @State private var amountText: String
    @State private var date: Date = .now
    @State private var refusal: ReimbursementPolicy.Failure?
    @State private var saveFailed = false

    init(claim: TransactionModel) {
        self.claim = claim
        _amountText = State(initialValue: Self.plainAmount(claim.unreimbursedAmount))
    }

    private var currencyCode: String {
        claim.account?.resolvedCurrencyCode ?? AppBaseCurrency.code
    }

    private var formattedBalance: String {
        Money.format(claim.unreimbursedAmount, currencyCode: currencyCode,
                     showsCents: showCents, locale: .appLocale)
    }

    private static func plainAmount(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent(String.appLocalized("Still owed"), value: formattedBalance)
                    TextField(String.appLocalized("Repayment amount"), text: $amountText)
                        #if os(iOS)
                        .keyboardType(.decimalPad)
                        #endif
                        .monospacedDigit()
                    DatePicker(String.appLocalized("Date"), selection: $date,
                               displayedComponents: .date)
                } footer: {
                    Text(String.appLocalized(
                        "Only the part still owed counts as your spending. The money returns to the account."))
                }

                if let message = refusalMessage {
                    Section {
                        Label(message, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(Color.AlertRed)
                    }
                }
            }
            .navigationTitle(String.appLocalized("Reimbursement"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String.appLocalized("Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String.appLocalized("Reimbursed")) { save() }
                }
            }
        }
    }

    private var refusalMessage: String? {
        if saveFailed { return String.appLocalized("Couldn't save the repayment.") }
        switch refusal {
        case .none:
            return nil
        case .notAClaim:
            return String.appLocalized("Only an expense waiting to be paid back can be reimbursed.")
        case .alreadyWrittenOff:
            return String.appLocalized("This claim was already written off.")
        case .nonPositiveAmount:
            return String.appLocalized("Enter an amount greater than zero.")
        case .exceedsRemaining:
            return String.appFormatted("That is more than the claim: %@ is still owed.",
                                       formattedBalance)
        }
    }

    private func save() {
        saveFailed = false
        refusal = nil
        guard let amount = ImportAmount.parse(amountText) else {
            refusal = .nonPositiveAmount
            return
        }
        switch transactionVM.recordReimbursement(claim, amount: amount, date: date) {
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
