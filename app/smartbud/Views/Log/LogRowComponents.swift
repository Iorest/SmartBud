//
//  LogRowComponents.swift
//  smartbud
//
//  Rows that are not plain transactions: the batch-selection action bar and
//  the transfer row shown inline in the ledger.
//

import SwiftUI

struct LogSelectionBar: View {
    let count: Int
    let expenseCategories: [CategoryModel]
    let incomeCategories: [CategoryModel]
    let books: [BookModel]
    let accounts: [AccountModel]
    let labels: [TagModel]
    let onPick: (CategoryModel) -> Void
    let onBook: (UUID) -> Void
    let onNote: () -> Void
    let onDate: () -> Void
    let onAccount: (UUID?) -> Void
    let onLabel: (UUID) -> Void
    let onReimbursable: (Bool) -> Void
    let onExcluded: (Bool) -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: SBSpace.medium) {
            Menu {
                Section(String.appLocalized("Expense")) {
                    ForEach(expenseCategories) { category in
                        categoryButton(category)
                    }
                }
                if !incomeCategories.isEmpty {
                    Section(String.appLocalized("Income")) {
                        ForEach(incomeCategories) { category in
                            categoryButton(category)
                        }
                    }
                }
            } label: {
                Label(String.appLocalized("Move to Category"), systemImage: "folder")
                    .font(.body.weight(.medium))
                    .accessibilityIdentifier(AccessibilityID.logBatchCategoryMenu)
            }

            Menu {
                Section(String.appLocalized("settings.row.books")) {
                    ForEach(books) { book in
                        Button(book.name) { onBook(book.id) }
                            .accessibilityIdentifier(AccessibilityID.logBatchBook)
                    }
                }
                Button(String.appLocalized("Note"), systemImage: "pencil") { onNote() }
                    .accessibilityIdentifier(AccessibilityID.logBatchNote)
                Button(String.appLocalized("Date"), systemImage: "calendar") { onDate() }
                    .accessibilityIdentifier(AccessibilityID.logBatchDate)
                Section(String.appLocalized("Account")) {
                    ForEach(accounts) { account in
                        Button("\(account.wrappedEmoji) \(account.wrappedName)") {
                            onAccount(account.id)
                        }
                    }
                }
                if !labels.isEmpty {
                    Section(String.appLocalized("Labels")) {
                        ForEach(labels) { tag in
                            Button(tag.name) { onLabel(tag.id) }
                        }
                    }
                }
                Section(String.appLocalized("Batch Edit")) {
                    Button(String.appLocalized("Mark as Reimbursable"), systemImage: "checkmark.circle") {
                        onReimbursable(true)
                    }
                    .accessibilityIdentifier(AccessibilityID.logBatchReimbursable)
                    Button(String.appLocalized("Exclude from Budget & Income/Expense"),
                           systemImage: "slash.circle") {
                        onExcluded(true)
                    }
                    .accessibilityIdentifier(AccessibilityID.logBatchExclude)
                }
            } label: {
                Label(String.appLocalized("Batch Edit"), systemImage: "slider.horizontal.3")
                    .font(.body.weight(.medium))
            }
            .accessibilityIdentifier(AccessibilityID.logBatchEditMenu)

            Spacer(minLength: 0)

            Button(role: .destructive) {
                onDelete()
            } label: {
                Label(String.appFormatted("Delete (%lld)", count), systemImage: "trash")
                    .font(.body.weight(.medium))
            }
            .foregroundStyle(Color.AlertRed)
        }
        .padding(.horizontal, SBSpace.medium)
        .padding(.vertical, SBSpace.small)
        .frame(maxWidth: .infinity)
        .background(.bar)
        .overlay(alignment: .top) { Divider() }
        .appTransition(.move(edge: .bottom).combined(with: .opacity))
    }

    private func categoryButton(_ category: CategoryModel) -> some View {
        Button("\(category.wrappedEmoji) \(category.wrappedName)") {
            onPick(category)
        }
        .accessibilityIdentifier(AccessibilityID.logBatchCategory)
    }
}

// MARK: - Day header

// MARK: - Day header

struct LogDayHeaderRow: View {
    let group: LogDayGroup

    @AppStorage("showCents", store: .appGroup) private var showCents: Bool = true
    @AppStorage("currency", store: .appGroup) private var currency: String = Locale
        .current
        .currency?
        .identifier ?? "USD"

    private var totalText: String {
        LogGrouping.currency(
            group.netTotal,
            code: currency,
            showCents: showCents,
            signed: true,
            income: group.netTotal >= 0
        )
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(LogGrouping.dayTitle(group.day))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.SubtitleText)
            Spacer(minLength: SBSpace.extraSmall)
            Text(totalText)
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(Color.SubtitleText)
                .lineLimit(1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(LogGrouping.dayTitle(group.day)), \(totalText)"
        )
    }
}

// MARK: - Transfer row

/// Ledger row for money moved between two accounts. Styled like a transaction
/// so the list reads as one timeline, but it carries no category or net amount.
struct LogTransferRow: View {
    let transfer: TransferModel

    @AppStorage("currency", store: .appGroup) private var currency: String =
        Locale.current.currency?.identifier ?? "USD"
    @AppStorage("showCents", store: .appGroup) private var showCents: Bool = true

    private var accountFlow: String {
        let source = transfer.source?.wrappedName ?? "—"
        let destination = transfer.destination?.wrappedName ?? "—"
        return "\(source) → \(destination)"
    }

    var body: some View {
        HStack(spacing: SBSpace.small) {
            Image(systemName: "arrow.left.arrow.right")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.SubtitleText)
                .frame(width: 40, height: 40)
                .background(Color.SecondaryBackground,
                            in: RoundedRectangle(cornerRadius: SBRadius.chip, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(String.appLocalized("Transfer"))
                    .font(.body.weight(.medium))
                    .foregroundStyle(Color.PrimaryText)
                Text("\(accountFlow) · \(timeText)")
                    .font(.caption)
                    .foregroundStyle(Color.SubtitleText)
                    .lineLimit(1)
            }

            Spacer(minLength: SBSpace.extraSmall)

            Text(amountText)
                .font(.callout.weight(.medium).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }

    /// The moved amount only: the fee is an expense row of its own, so adding
    /// it here would show the same 2.50 twice.
    private var amountText: String {
        let outgoing = transfer.source?.resolvedCurrencyCode ?? currency
        let sent = Money.format(transfer.amount, currencyCode: outgoing,
                                showsCents: showCents, locale: .appLocale)
        guard transfer.destinationAmount > 0 else { return sent }

        let incoming = transfer.destination?.resolvedCurrencyCode ?? currency
        let landed = Money.format(transfer.receivedAmount, currencyCode: incoming,
                                  showsCents: showCents, locale: .appLocale)
        return "\(sent) → \(landed)"
    }

    private var timeText: String {
        transfer.wrappedDate.formatted(
            Date.FormatStyle(locale: Locale.appLocale).hour().minute())
    }
}
