//
//  AccountListView+Sections.swift
//  smartbud
//
//  Row builders, the archived section and the balance-adjustment flow.
//  Split from AccountListView.swift to keep the type body readable.
//

import SwiftData
import SwiftUI

extension AccountListView {

    var totalRow: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(String.appLocalized("Total Balance"))
                .font(.subheadline)
                .foregroundStyle(Color.SubtitleText)
            Spacer()
            Text(Money.format(accountVM.totalBalance, currencyCode: currency,
                              showsCents: showCents, locale: .appLocale))
                .font(.title3.weight(.semibold).monospacedDigit())
                .accessibilityIdentifier(AccessibilityID.accountsTotal)
        }
        .padding(.vertical, SBSpace.xxs)
        .listRowSeparator(.hidden)
    }

    func transferAmountText(_ transfer: TransferModel) -> String {
        let outgoing = transfer.source?.resolvedCurrencyCode ?? currency
        let sent = Money.format(transfer.amount, currencyCode: outgoing,
                                showsCents: showCents, locale: .appLocale)
        // The fee is its own expense row now, so folding it in here would show
        // the same amount twice.
        guard transfer.destinationAmount > 0 else { return sent }

        let incoming = transfer.destination?.resolvedCurrencyCode ?? currency
        let landed = Money.format(transfer.receivedAmount, currencyCode: incoming,
                                  showsCents: showCents, locale: .appLocale)
        return "\(sent) → \(landed)"
    }

    func kindLabel(_ account: AccountModel) -> String {
        let kind = String.appLocalized(
            AccountKind(rawValue: account.kind)?.titleKey ?? AccountKind.cash.titleKey)
        let code = account.resolvedCurrencyCode
        return code == currency ? kind : "\(kind) · \(code)"
    }

    func transferRow(_ transfer: TransferModel) -> some View {
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

            Text(transferAmountText(transfer))
                .font(.callout.weight(.medium).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(AccessibilityID.accountsTransferRow)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                transferToDelete = transfer
            } label: {
                Label(String.appLocalized("Delete"), systemImage: "trash")
            }
        }
    }

    func row(_ account: AccountModel) -> some View {
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
                Text(kindLabel(account))
                    .font(.caption)
                    .foregroundStyle(Color.SubtitleText)
            }

            Spacer(minLength: SBSpace.extraSmall)

            Text(Money.format(accountVM.balance(for: account),
                              currencyCode: account.resolvedCurrencyCode,
                              showsCents: showCents, locale: .appLocale))
                .font(.callout.weight(.medium).monospacedDigit())
                .foregroundStyle(accountVM.balance(for: account) < 0
                                 ? Color.AlertRed : Color.PrimaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier(AccessibilityID.accountsRow)
        .onTapGesture { editing = account }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            rowSwipeActions(for: account)
        }
        .contextMenu {
            Button {
                startAdjustment(account)
            } label: {
                Label(String.appLocalized("Adjust Balance"), systemImage: "equal.circle")
            }
            Button {
                requestArchiveToggle(for: account)
            } label: {
                Label(String.appLocalized(account.archived ? "Unarchive" : "Archive"),
                      systemImage: "archivebox")
            }
        }
        .opacity(account.hidden ? 0.45 : 1)
    }

    /// Unarchiving is harmless; archiving with money left asks first.
    func requestArchiveToggle(for account: AccountModel) {
        if account.archived {
            accountVM.setArchived(false, for: account)
            return
        }
        let balance = accountVM.balance(for: account)
        if abs(balance) < 0.005 {
            accountVM.setArchived(true, for: account)
        } else {
            archivingAccount = account
        }
    }

    @ViewBuilder
    private func rowSwipeActions(for account: AccountModel) -> some View {
        Button(role: .destructive) {
            toDelete = account
        } label: {
            Label(String.appLocalized("Delete"), systemImage: "trash")
        }
        Button {
            requestArchiveToggle(for: account)
        } label: {
            Label(String.appLocalized(account.archived ? "Unarchive" : "Archive"),
                  systemImage: account.archived ? "tray.and.arrow.up" : "archivebox")
        }
        .accessibilityIdentifier(AccessibilityID.accountsRowArchive)
        .tint(.orange)
        Button {
            accountVM.setHidden(!account.hidden, for: account)
        } label: {
            Label(String.appLocalized(account.hidden ? "Show" : "Hide"),
                  systemImage: account.hidden ? "eye" : "eye.slash")
        }
        .accessibilityIdentifier(AccessibilityID.accountsRowHide)
        .tint(.gray)
    }
}
