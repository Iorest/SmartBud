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
    @State private var date = Date.now
    @State private var note = ""

    @AppStorage("currency", store: .appGroup) private var currency: String =
        Locale.current.currency?.identifier ?? "USD"

    private var accounts: [AccountModel] { accountVM.visibleAccounts }

    private var parsedAmount: Double {
        Double(amount.replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    private var canSave: Bool {
        guard let source, let destination else { return false }
        return source.id != destination.id && parsedAmount > 0 && parsedAmount.isFinite
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
                    HStack(spacing: SBSpace.extraSmall) {
                        Text(String.appLocalized("Amount"))
                        Spacer()
                        TextField("0", text: $amount)
                            #if os(iOS)
                            .keyboardType(.decimalPad)
                            #endif
                            .multilineTextAlignment(.trailing)
                            .monospacedDigit()
                        // Single-currency app: show the unit so the number is
                        // unambiguous (accounts share the app currency).
                        Text(currency)
                            .font(.footnote)
                            .foregroundStyle(Color.SubtitleText)
                    }
                    DatePicker(String.appLocalized("Date"), selection: $date, displayedComponents: .date)
                    TextField(String.appLocalized("Note"), text: $note)
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
        }
    }

    private func pickDefaults() {
        accountVM.load()
        if source == nil { source = accounts.first }
        if destination == nil { destination = accounts.first { $0.id != source?.id } }
    }

    private func save() {
        guard let source, let destination else { return }
        accountVM.createTransfer(
            source: source,
            destination: destination,
            amount: parsedAmount,
            date: date,
            note: note
        )
        dismiss()
    }
}
