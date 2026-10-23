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
                    Picker(String.appLocalized("To"), selection: $destination) {
                        ForEach(accounts) { account in
                            Text("\(account.wrappedEmoji) \(account.wrappedName)").tag(Optional(account))
                        }
                    }
                }

                Section {
                    amountRow(titleKey: "Amount", text: $amount, code: sourceCurrency)

                    amountRow(titleKey: "Fee", text: $fee, code: sourceCurrency)

                    if isCrossCurrency {
                        amountRow(titleKey: "Amount Received",
                                  text: $destinationAmount, code: destinationCurrency)

                        Text(rateHint)
                            .font(.footnote)
                            .foregroundStyle(Color.SubtitleText)
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
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String.appLocalized("Done")) { save() }
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
    /// accounts use different currencies. The user can overwrite it with what
    /// the bank actually credited.
    private func suggestDestinationAmount() {
        guard isCrossCurrency, parsedAmount > 0 else { return }
        let converted = parsedAmount * rateStore.rate(from: sourceCurrency, to: destinationCurrency)
        destinationAmount = String(format: "%.2f", (converted * 100).rounded() / 100)
    }

    private var rateHint: String {
        let rate = rateStore.rate(from: sourceCurrency, to: destinationCurrency)
        return String.appFormatted("1 %@ = %@ %@",
                                   sourceCurrency,
                                   rate.formatted(.number.precision(.fractionLength(4))),
                                   destinationCurrency)
    }

    @ViewBuilder
    private func amountRow(titleKey: String, text: Binding<String>, code: String) -> some View {
        HStack(spacing: SBSpace.extraSmall) {
            Text(String.appLocalized(titleKey))
            Spacer()
            TextField("0", text: text)
                #if os(iOS)
                .keyboardType(.decimalPad)
                #endif
                .multilineTextAlignment(.trailing)
                .monospacedDigit()
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
