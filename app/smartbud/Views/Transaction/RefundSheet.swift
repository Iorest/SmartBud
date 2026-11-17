//
//  RefundSheet.swift
//  smartbud
//
//  Records money coming back for a purchase. Three things the sheet has to get
//  right (docs/accounting-conventions.md §3): the amount, the day it arrived,
//  and the account it landed in. The remaining amount and the frozen exchange
//  rate are not entered — they follow from the original row.
//

import SwiftData
import SwiftUI

/// What the sheet is opened for. `refund == nil` means "record a new one for
/// `original`"; otherwise the existing refund row is being edited.
struct RefundTarget: Identifiable {
    let original: TransactionModel
    let refund: TransactionModel?

    var id: UUID { refund?.id ?? original.id }
}

struct RefundSheet: View {
    @Environment(TransactionViewModel.self) private var transactionVM
    @Environment(AccountViewModel.self) private var accountVM
    @Environment(InsightsViewModel.self) private var insightsVM
    @Environment(\.dismiss) private var dismiss

    @AppStorage("showCents", store: .appGroup) private var showCents: Bool = true

    private let target: RefundTarget

    @State private var amountText: String
    @State private var date: Date
    @State private var account: AccountModel?
    @State private var refusal: RefundPolicy.Failure?
    @State private var saveFailed = false

    init(target: RefundTarget) {
        self.target = target
        _amountText = State(initialValue: Self.initialAmount(for: target))
        _date = State(initialValue: target.refund?.wrappedDate ?? .now)
        _account = State(initialValue: target.refund?.account ?? target.original.account)
    }

    // MARK: - Derived

    private var original: TransactionModel { target.original }

    private var currencyCode: String {
        original.account?.resolvedCurrencyCode ?? AppBaseCurrency.code
    }

    /// A refund converts with the purchase's frozen rate, which only applies
    /// inside one currency — the picker offers accounts the money can land in.
    private var refundableAccounts: [AccountModel] {
        var list = accountVM.visibleAccounts.filter {
            $0.resolvedCurrencyCode == currencyCode
        }
        // The account that paid (or will receive) stays selectable even when it
        // is hidden or archived: the money still has to land somewhere, and the
        // picker must show a checkmark instead of looking unset.
        if let selected = account, !list.contains(where: { $0.id == selected.id }) {
            list.insert(selected, at: 0)
        }
        return list
    }

    /// What this sheet may still use: the original's remaining amount plus the
    /// amount already in the row being edited.
    private var budget: Double {
        let remaining = transactionVM.remainingRefundable(for: original)
        return remaining + (target.refund?.amount ?? 0)
    }

    private var formattedRemaining: String {
        Money.format(budget, currencyCode: currencyCode,
                     showsCents: showCents, locale: .appLocale)
    }

    private static func initialAmount(for target: RefundTarget) -> String {
        if let refund = target.refund { return plainAmount(refund.amount) }
        return ""
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

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text(String.appLocalized("Still refundable"))
                        Spacer()
                        Text(formattedRemaining)
                            .foregroundStyle(Color.SubtitleText)
                            .monospacedDigit()
                            .accessibilityIdentifier(AccessibilityID.refundRemaining)
                    }

                    TextField(String.appLocalized("Refund amount"), text: $amountText)
                        #if os(iOS)
                        .keyboardType(.decimalPad)
                        #endif
                        .monospacedDigit()
                        .accessibilityIdentifier(AccessibilityID.refundAmount)

                    DatePicker(String.appLocalized("Date"), selection: $date,
                               displayedComponents: .date)

                    Picker(String.appLocalized("Account"), selection: $account) {
                        Text(String.appLocalized("None")).tag(AccountModel?.none)
                        ForEach(refundableAccounts) { candidate in
                            Text(candidate.wrappedName).tag(AccountModel?.some(candidate))
                        }
                    }
                } footer: {
                    Text(String.appLocalized(
                        "Money given back reduces the expense in the period it arrives. It is never counted as income."))
                }

                if let message = refusalMessage {
                    Section {
                        Label(message, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(Color.AlertRed)
                    }
                }
            }
            .navigationTitle(target.refund == nil
                             ? String.appLocalized("Refund")
                             : String.appLocalized("Edit Refund"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String.appLocalized("Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String.appLocalized("Save")) { save() }
                        .accessibilityIdentifier(AccessibilityID.refundSave)
                }
            }
        }
        .onAppear { accountVM.load() }
    }

    private var refusalMessage: String? {
        if saveFailed { return String.appLocalized("Couldn't save the refund.") }
        switch refusal {
        case .none:
            return nil
        case .notAnExpense:
            return String.appLocalized("Only an expense can be refunded.")
        case .nonPositiveAmount:
            return String.appLocalized("Enter an amount greater than zero.")
        case .exceedsRemaining(let remaining):
            let value = Money.format(remaining, currencyCode: currencyCode,
                                     showsCents: showCents, locale: .appLocale)
            return String.appFormatted("That is more than the purchase: %@ is still refundable.", value)
        case .arrivedBeforeExpense:
            return String.appLocalized("The refund cannot arrive before the purchase.")
        case .currencyMismatch:
            return String.appLocalized("The refund must land in the same currency as the purchase.")
        }
    }

    // MARK: - Save

    private func save() {
        saveFailed = false
        refusal = nil
        guard let amount = ImportAmount.parse(amountText) else {
            refusal = .nonPositiveAmount
            return
        }

        let result: TransactionViewModel.RefundResult
        if let refund = target.refund {
            result = transactionVM.updateRefund(refund, amount: amount, date: date,
                                                account: account)
        } else {
            result = transactionVM.addRefund(to: original, amount: amount, date: date,
                                             account: account)
        }

        switch result {
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
