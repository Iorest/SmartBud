//
//  AccountListView.swift
//  smartbud
//
//  Accounts screen: balances derived from the opening balance plus every
//  linked transaction. Deleting an account keeps its transactions and clears
//  the link, matching how categories behave.
//

import SwiftData
import SwiftUI

struct AccountListView: View {
    @Environment(AccountViewModel.self) var accountVM

    @AppStorage("currency", store: .appGroup) var currency: String =
        Locale.current.currency?.identifier ?? "USD"
    @AppStorage("showCents", store: .appGroup) var showCents: Bool = true

    @State var showEditor = false
    @State var showTransfer = false
    @State var editing: AccountModel?
    @State var toDelete: AccountModel?
    @State var transferToDelete: TransferModel?
    @State var showArchived = false
    @State var adjusting: AccountModel?
    @State var adjustmentInput = ""

    var body: some View {
        List {
            Section {
                totalRow
            }

            if accountVM.accounts.isEmpty {
                Section {
                    SBEmptyState(
                        systemImage: "creditcard",
                        title: String.appLocalized("No accounts yet"),
                        message: String.appLocalized(
                            "Add the cards and wallets you pay from to see where the money goes."),
                        actionTitle: String.appLocalized("New Account"),
                        action: { showEditor = true }
                    )
                    .listRowSeparator(.hidden)
                }
            } else {
                Section {
                    ForEach(accountVM.visibleAccounts) { account in
                        row(account)
                    }
                }

                if !accountVM.archivedAccounts.isEmpty {
                    archivedSection
                }

                if !accountVM.transfers.isEmpty {
                    Section(String.appLocalized("Transfers")) {
                        ForEach(accountVM.transfers) { transfer in
                            transferRow(transfer)
                        }
                    }
                }
            }
        }
        .navigationTitle(String.appLocalized("Accounts"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showTransfer = true
                } label: {
                    Image(systemName: "arrow.left.arrow.right")
                }
                .accessibilityLabel(String.appLocalized("Transfer"))
                .disabled(accountVM.visibleAccounts.count < 2)
            }

            ToolbarItem(placement: .primaryAction) {
                Button {
                    showEditor = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel(String.appLocalized("New Account"))
            }
        }
        .onAppear { accountVM.load() }
        .sheet(isPresented: $showEditor) {
            AccountEditor(account: nil)
                .environment(accountVM)
        }
        .sheet(isPresented: $showTransfer) {
            TransferEditor()
                .environment(accountVM)
        }
        .alert(
            String.appLocalized("Delete this transfer?"),
            isPresented: Binding(
                get: { transferToDelete != nil },
                set: { if !$0 { transferToDelete = nil } }
            )
        ) {
            Button(String.appLocalized("Delete"), role: .destructive) {
                if let transferToDelete {
                    accountVM.deleteTransfer(transferToDelete)
                }
                transferToDelete = nil
            }
            Button(String.appLocalized("Cancel"), role: .cancel) { transferToDelete = nil }
        } message: {
            Text(String.appLocalized("Both account balances go back to what they were."))
        }
        .sheet(item: $editing) { account in
            AccountEditor(account: account)
                .environment(accountVM)
        }
        .alert(
            String.appFormatted("Delete '%@'?", toDelete?.wrappedName ?? ""),
            isPresented: Binding(
                get: { toDelete != nil },
                set: { if !$0 { toDelete = nil } }
            ),
            presenting: toDelete
        ) { account in
            Button(String.appLocalized("Delete"), role: .destructive) {
                accountVM.delete(account)
                toDelete = nil
            }
            Button(String.appLocalized("Cancel"), role: .cancel) { toDelete = nil }
        } message: { _ in
            Text(String.appLocalized("Transactions in this account are kept and become unassigned."))
        }
        .alert(
            String.appLocalized("Adjust Balance"),
            isPresented: Binding(
                get: { adjusting != nil },
                set: { if !$0 { adjusting = nil } }
            )
        ) {
            TextField("0", text: $adjustmentInput)
                #if os(iOS)
                .keyboardType(.decimalPad)
                #endif
            Button(String.appLocalized("Cancel"), role: .cancel) {
                adjusting = nil
                adjustmentInput = ""
            }
            Button(String.appLocalized("Done")) { applyAdjustment() }
        } message: {
            Text(adjustmentMessage)
        }
    }

    /// Archived accounts drop out of the daily list and the total but keep
    /// every transaction, transfer and report that references them.
    var archivedSection: some View {
        Section {
            if showArchived {
                ForEach(accountVM.archivedAccounts) { account in
                    row(account)
                }
            }

            Button {
                withAnimation(.easeInOut(duration: 0.2)) { showArchived.toggle() }
            } label: {
                Text(showArchived
                     ? String.appLocalized("Hide Archived Accounts")
                     : String.appFormatted("Show Archived Accounts (%lld)",
                                           accountVM.archivedAccounts.count))
            }
        } header: {
            Text(String.appLocalized("Archived"))
        } footer: {
            Text(String.appLocalized(
                "Archived accounts keep their history but are left out of the total balance."))
        }
    }

    var adjustmentMessage: String {
        guard let account = adjusting else { return "" }
        let current = Money.format(accountVM.balance(for: account),
                                   currencyCode: account.resolvedCurrencyCode,
                                   showsCents: showCents, locale: .appLocale)
        return String.appFormatted(
            "Records a balance correction for “%@” (now %@). The opening balance stays as it is.",
            account.wrappedName, current)
    }

    func startAdjustment(_ account: AccountModel) {
        adjusting = account
        let current = Money.double(Money.cents(accountVM.balance(for: account)))
        adjustmentInput = String(format: "%.2f", current)
    }

    func applyAdjustment() {
        guard let account = adjusting else { return }
        defer {
            adjusting = nil
            adjustmentInput = ""
        }
        let cleaned = adjustmentInput
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: ",", with: ".")
        guard let target = Double(cleaned), target.isFinite else { return }
        accountVM.adjustBalance(account, to: target)
    }
}
