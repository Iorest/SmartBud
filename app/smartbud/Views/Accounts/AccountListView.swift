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
    @Environment(AccountViewModel.self) private var accountVM

    @AppStorage("currency", store: .appGroup) private var currency: String =
        Locale.current.currency?.identifier ?? "USD"
    @AppStorage("showCents", store: .appGroup) private var showCents: Bool = true

    @State private var showEditor = false
    @State private var showTransfer = false
    @State private var editing: AccountModel?
    @State private var toDelete: AccountModel?
    @State private var transferToDelete: TransferModel?

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
                    ForEach(accountVM.accounts) { account in
                        row(account)
                    }
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
    }

    private var totalRow: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(String.appLocalized("Total Balance"))
                .font(.subheadline)
                .foregroundStyle(Color.SubtitleText)
            Spacer()
            Text(Money.format(accountVM.totalBalance, currencyCode: currency,
                              showsCents: showCents, locale: .appLocale))
                .font(.title3.weight(.semibold).monospacedDigit())
        }
        .padding(.vertical, SBSpace.xxs)
        .listRowSeparator(.hidden)
    }

    private func transferRow(_ transfer: TransferModel) -> some View {
        HStack(spacing: SBSpace.small) {
            Image(systemName: "arrow.left.arrow.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.SubtitleText)
                .frame(width: 36, height: 36)
                .background(Color.SecondaryBackground,
                            in: RoundedRectangle(cornerRadius: SBRadius.chip, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text("\(transfer.source?.wrappedName ?? "—") → \(transfer.destination?.wrappedName ?? "—")")
                    .font(.body.weight(.medium))
                    .foregroundStyle(Color.PrimaryText)
                Text(transfer.wrappedDate.formatted(
                    Date.FormatStyle(locale: Locale.appLocale).month(.abbreviated).day().hour().minute()))
                    .font(.caption)
                    .foregroundStyle(Color.SubtitleText)
            }

            Spacer(minLength: SBSpace.extraSmall)

            Text(Money.format(transfer.amount, currencyCode: currency,
                              showsCents: showCents, locale: .appLocale))
                .font(.callout.weight(.medium).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.vertical, 2)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                transferToDelete = transfer
            } label: {
                Label(String.appLocalized("Delete"), systemImage: "trash")
            }
        }
    }

    private func row(_ account: AccountModel) -> some View {
        HStack(spacing: SBSpace.small) {
            Text(account.wrappedEmoji.isEmpty ? "💳" : account.wrappedEmoji)
                .font(.title3)
                .frame(width: 36, height: 36)
                .background(Color(hex: account.wrappedColour).opacity(0.25),
                            in: RoundedRectangle(cornerRadius: SBRadius.chip, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(account.wrappedName)
                    .font(.body.weight(.medium))
                    .foregroundStyle(Color.PrimaryText)
                Text(String.appLocalized(
                    AccountKind(rawValue: account.kind)?.titleKey ?? AccountKind.cash.titleKey
                ))
                .font(.caption)
                .foregroundStyle(Color.SubtitleText)
            }

            Spacer(minLength: SBSpace.extraSmall)

            Text(Money.format(accountVM.balance(for: account), currencyCode: currency,
                              showsCents: showCents, locale: .appLocale))
                .font(.callout.weight(.medium).monospacedDigit())
                .foregroundStyle(accountVM.balance(for: account) < 0
                                 ? Color.AlertRed : Color.PrimaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .onTapGesture { editing = account }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                toDelete = account
            } label: {
                Label(String.appLocalized("Delete"), systemImage: "trash")
            }
            Button {
                accountVM.setHidden(!account.hidden, for: account)
            } label: {
                Label(String.appLocalized(account.hidden ? "Show" : "Hide"),
                      systemImage: account.hidden ? "eye" : "eye.slash")
            }
            .tint(.gray)
        }
        .opacity(account.hidden ? 0.45 : 1)
    }
}
