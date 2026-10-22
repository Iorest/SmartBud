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
    @State private var editing: AccountModel?
    @State private var toDelete: AccountModel?

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
            }
        }
        .navigationTitle(String.appLocalized("Accounts"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
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

// MARK: - Editor

struct AccountEditor: View {
    @Environment(AccountViewModel.self) private var accountVM
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var typeSize

    let account: AccountModel?

    @State private var name = ""
    @State private var emoji = "💳"
    @State private var colour = Theme.Palette.swatches.first ?? "#279AF4"
    @State private var kind: AccountKind = .cash
    @State private var openingBalance = ""

    private var isEditing: Bool { account != nil }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: SBSpace.small) {
                        TextField("🙂", text: $emoji)
                            .font(.title2)
                            .multilineTextAlignment(.center)
                            .frame(width: 44)
                            .onChange(of: emoji) { _, new in
                                emoji = String(new.onlyEmoji().prefix(1))
                            }

                        TextField(String.appLocalized("Account name"), text: $name)
                    }
                }

                Section(String.appLocalized("Type")) {
                    Picker(String.appLocalized("Type"), selection: $kind) {
                        ForEach(AccountKind.allCases) { kind in
                            Text(String.appLocalized(kind.titleKey)).tag(kind)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }

                Section {
                    HStack {
                        Text(String.appLocalized("Opening Balance"))
                        Spacer()
                        TextField("0", text: $openingBalance)
                            #if os(iOS)
                            .keyboardType(.decimalPad)
                            #endif
                            .multilineTextAlignment(.trailing)
                            .monospacedDigit()
                    }
                } footer: {
                    Text(String.appLocalized(
                        "The balance before any transaction is recorded in this account."))
                }

                Section(String.appLocalized("Colour")) {
                    colourGrid
                }
            }
            .formStyle(.grouped)
            .navigationTitle(isEditing
                             ? String.appLocalized("Edit Account")
                             : String.appLocalized("New Account"))
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
            .onAppear(perform: loadValues)
        }
    }

    @ViewBuilder
    private var colourGrid: some View {
        let columns = [GridItem(.adaptive(minimum: 34), spacing: SBSpace.small)]
        LazyVGrid(columns: columns, spacing: SBSpace.small) {
            ForEach(Theme.Palette.swatches, id: \.self) { hex in
                Circle()
                    .fill(Color(hex: hex))
                    .frame(width: 30, height: 30)
                    .overlay {
                        if hex == colour {
                            Image(systemName: "checkmark")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white)
                        }
                    }
                    .contentShape(Circle())
                    .onTapGesture { colour = hex }
                    .accessibilityLabel(Text(hex))
                    .accessibilityAddTraits(hex == colour ? .isSelected : [])
            }
        }
    }

    private func loadValues() {
        guard let account else {
            openingBalance = ""
            return
        }
        name = account.wrappedName
        emoji = account.wrappedEmoji
        colour = account.wrappedColour
        kind = AccountKind(rawValue: account.kind) ?? .cash
        openingBalance = account.openingBalance == 0
            ? ""
            : String(format: "%.2f", account.openingBalance)
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let opening = Double(openingBalance.replacingOccurrences(of: ",", with: ".")) ?? 0
        guard opening.isFinite else { return }

        let draft = AccountDraft(name: trimmedName, emoji: emoji, colour: colour,
                                 kind: kind, openingBalance: opening)
        if let account {
            accountVM.update(account, with: draft)
        } else {
            accountVM.create(draft)
        }
        dismiss()
    }
}

// MARK: - Entry-form chip and picker

/// Compact chip shown above the date/category row of the entry form.
struct TransactionAccountChip: View {
    let account: AccountModel?
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 5) {
                Image(systemName: "creditcard")
                    .font(.caption.weight(.semibold))
                Text(account?.wrappedName ?? String.appLocalized("Account"))
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
            }
            .foregroundStyle(account == nil ? Color.SubtitleText : Color.PrimaryText)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.SecondaryBackground,
                        in: RoundedRectangle(cornerRadius: SBRadius.chip, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(String.appFormatted("Account: %@",
            account?.wrappedName ?? String.appLocalized("None"))))
    }
}

/// Sheet listing every account, used from the entry form.
struct AccountPickerSheet: View {
    @Binding var selection: AccountModel?
    @Environment(AccountViewModel.self) private var accountVM
    @Environment(\.dismiss) private var dismiss

    @AppStorage("currency", store: .appGroup) private var currency: String =
        Locale.current.currency?.identifier ?? "USD"

    var body: some View {
        NavigationStack {
            List {
                Button {
                    selection = nil
                    dismiss()
                } label: {
                    HStack {
                        Label(String.appLocalized("No Account"), systemImage: "minus.circle")
                        Spacer()
                        if selection == nil {
                            Image(systemName: "checkmark").foregroundStyle(Color.accentColor)
                        }
                    }
                }
                .buttonStyle(.plain)

                ForEach(accountVM.visibleAccounts) { account in
                    Button {
                        selection = account
                        dismiss()
                    } label: {
                        HStack(spacing: SBSpace.small) {
                            Text(account.wrappedEmoji.isEmpty ? "💳" : account.wrappedEmoji)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(account.wrappedName)
                                Text(Money.format(accountVM.balance(for: account),
                                                  currencyCode: currency, locale: .appLocale))
                                    .font(.caption)
                                    .foregroundStyle(Color.SubtitleText)
                            }
                            Spacer()
                            if selection?.id == account.id {
                                Image(systemName: "checkmark").foregroundStyle(Color.accentColor)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle(String.appLocalized("Account"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String.appLocalized("Cancel")) { dismiss() }
                }
            }
            .onAppear { accountVM.load() }
        }
    }
}
