//
//  TransferEditor.swift
//  smartbud
//

import SwiftUI

// MARK: - Transfer editor

struct TransferEditor: View {
    @Environment(AccountViewModel.self) private var accountVM
    @Environment(\.dismiss) private var dismiss

    @State private var source: AccountModel?
    @State private var destination: AccountModel?
    @State private var amount = ""
    @State private var destinationAmount = ""
    @State private var fee = ""
    /// Last value written by `suggestDestinationAmount`, so a manual edit is
    /// never overwritten by the next keystroke in the amount field.
    @State private var lastSuggestedDestination = ""
    @State private var date = Date.now
    @State private var note = ""

    @AppStorage("currency", store: .appGroup) private var currency: String =
        Locale.current.currency?.identifier ?? "USD"

    @Environment(CurrencyRateStore.self) private var rateStore

    private var accounts: [AccountModel] { accountVM.visibleAccounts }

    private var parsedAmount: Double {
        Double(amount.replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    private var parsedDestinationAmount: Double {
        Double(destinationAmount.replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    private var parsedFee: Double {
        fee.isEmpty ? 0 : (Double(fee.replacingOccurrences(of: ",", with: ".")) ?? 0)
    }

    private var isCrossCurrency: Bool {
        guard let source, let destination else { return false }
        return source.resolvedCurrencyCode != destination.resolvedCurrencyCode
    }

    private var sourceCurrency: String { source?.resolvedCurrencyCode ?? currency }
    private var destinationCurrency: String { destination?.resolvedCurrencyCode ?? currency }

    /// Whether both currencies have a stored rate. Without one the app used
    /// to pre-fill the received amount at 1:1, which is a made-up exchange
    /// rate the user could save by accident.
    private var hasRate: Bool {
        guard isCrossCurrency else { return true }
        return !rateStore.needsRate(for: sourceCurrency)
            && !rateStore.needsRate(for: destinationCurrency)
    }

    private var canSave: Bool {
        guard let source, let destination else { return false }
        guard source.id != destination.id, parsedAmount > 0, parsedAmount.isFinite else { return false }
        guard parsedFee >= 0, parsedFee.isFinite else { return false }
        guard isCrossCurrency else { return true }
        return parsedDestinationAmount > 0 && parsedDestinationAmount.isFinite
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker(String.appLocalized("From"), selection: $source) {
                        ForEach(accounts) { account in
                            Text("\(account.wrappedEmoji) \(account.wrappedName)").tag(Optional(account))
                        }
                    }
                    .accessibilityIdentifier(AccessibilityID.transferSource)
                    Picker(String.appLocalized("To"), selection: $destination) {
                        ForEach(accounts) { account in
                            Text("\(account.wrappedEmoji) \(account.wrappedName)").tag(Optional(account))
                        }
                    }
                    .accessibilityIdentifier(AccessibilityID.transferDestination)
                }

                Section {
                    amountRow(titleKey: "Amount", text: $amount, code: sourceCurrency,
                              identifier: AccessibilityID.transferAmount)

                    amountRow(titleKey: "Fee", text: $fee, code: sourceCurrency,
                              identifier: AccessibilityID.transferFee)

                    if isCrossCurrency {
                        amountRow(titleKey: "Amount Received",
                                  text: $destinationAmount, code: destinationCurrency,
                                  identifier: AccessibilityID.transferDestinationAmount)

                        if let rateHint {
                            Text(rateHint)
                                .font(.footnote)
                                .foregroundStyle(Color.SubtitleText)
                        }
                    }

                    DatePicker(String.appLocalized("Date"), selection: $date, displayedComponents: .date)
                    TextField(String.appLocalized("Note"), text: $note)
                } footer: {
                    if isCrossCurrency {
                        Text(String.appLocalized(
                            "Enter what actually arrived. The rate is stored with the transfer, "
                                + "so later rate changes never rewrite it."))
                    } else {
                        Text(String.appLocalized(
                            "The fee is charged on top of the amount and recorded as its own "
                                + "expense, so it shows up in your spending."))
                    }
                }

                if source?.id == destination?.id, source != nil {
                    Section {
                        Label(String.appLocalized("Pick two different accounts."),
                              systemImage: "exclamationmark.triangle")
                            .foregroundStyle(Color.AlertRed)
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle(String.appLocalized("Transfer"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String.appLocalized("Cancel")) { dismiss() }
                        .accessibilityIdentifier(AccessibilityID.transferCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String.appLocalized("Done")) { save() }
                        .accessibilityIdentifier(AccessibilityID.transferSave)
                        .disabled(!canSave)
                }
            }
            .onAppear(perform: pickDefaults)
            .onChange(of: amount) { _, _ in suggestDestinationAmount() }
            .onChange(of: source) { _, _ in suggestDestinationAmount() }
            .onChange(of: destination) { _, _ in suggestDestinationAmount() }
        }
    }

    private func pickDefaults() {
        accountVM.load()
        rateStore.load()
        if source == nil { source = accounts.first }
        if destination == nil { destination = accounts.first { $0.id != source?.id } }
    }

    /// Pre-fills the received amount from the stored rates when the two
    /// accounts use different currencies. Never overwrites a number the user
    /// typed, and never invents a 1:1 rate when one is missing.
    private func suggestDestinationAmount() {
        guard isCrossCurrency, parsedAmount > 0, hasRate else {
            if isCrossCurrency && !hasRate {
                destinationAmount = ""
                lastSuggestedDestination = ""
            }
            return
        }
        let current = destinationAmount
        guard current.isEmpty || current == lastSuggestedDestination else { return }

        let converted = parsedAmount * rateStore.rate(from: sourceCurrency, to: destinationCurrency)
        let formatted = String(format: "%.2f", (converted * 100).rounded() / 100)
        destinationAmount = formatted
        lastSuggestedDestination = formatted
    }

    /// Nil when there is no stored rate: showing "1 USD = 1.0000 CNY" was a
    /// fabricated rate.
    private var rateHint: String? {
        guard hasRate else { return nil }
        let rate = rateStore.rate(from: sourceCurrency, to: destinationCurrency)
        return String.appFormatted("1 %@ = %@ %@",
                                   sourceCurrency,
                                   rate.formatted(.number.precision(.fractionLength(4))),
                                   destinationCurrency)
    }

    @ViewBuilder
    private func amountRow(titleKey: String, text: Binding<String>, code: String,
                           identifier: String) -> some View {
        HStack(spacing: SBSpace.extraSmall) {
            Text(String.appLocalized(titleKey))
            Spacer()
            TextField("0", text: text)
                #if os(iOS)
                .keyboardType(.decimalPad)
                #endif
                .multilineTextAlignment(.trailing)
                .monospacedDigit()
                .accessibilityIdentifier(identifier)
            Text(code)
                .font(.footnote)
                .foregroundStyle(Color.SubtitleText)
        }
    }

    private func save() {
        guard let source, let destination else { return }
        accountVM.createTransfer(
            source: source,
            destination: destination,
            amount: parsedAmount,
            destinationAmount: isCrossCurrency ? parsedDestinationAmount : 0,
            fee: parsedFee,
            date: date,
            note: note
        )
        dismiss()
    }
}
