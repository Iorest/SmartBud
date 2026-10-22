//
//  LogTransactionRow.swift
//  smartbud
//
import SwiftData
import SwiftUI

struct LogTransactionRow: View {
    let transaction: TransactionModel
    var future: Bool = false

    @AppStorage("showCents", store: .appGroup) private var showCents: Bool = true
    @AppStorage("currency", store: .appGroup) private var currency: String = Locale
        .current
        .currency?
        .identifier ?? "USD"
    @AppStorage("swapTimeLabel", store: .appGroup) private var swapTimeLabel: Bool = false
    @AppStorage("showExpenseOrIncomeSign", store: .appGroup) private var showExpenseOrIncomeSign: Bool = true

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var amountText: String {
        LogGrouping.currency(
            transaction.amount,
            // Amounts are denominated in the account's currency; rows without
            // an account fall back to the app's base currency.
            code: transaction.account?.resolvedCurrencyCode ?? currency,
            showCents: showCents,
            signed: showExpenseOrIncomeSign,
            income: transaction.income
        )
    }

    private var subtitle: String {
        if future {
            return dateFormatter(date: transaction.wrappedDate > .now
                                 ? transaction.wrappedDate
                                 : transaction.nextTransactionDate)
        }
        if swapTimeLabel {
            return transaction.wrappedCategoryName
        }

        let time = transaction.wrappedDate.formatted(
            Date.FormatStyle(locale: Locale.appLocale).hour().minute()
        )
        // Account name rides along with the time so the ledger answers
        // "which card was this" without opening the row.
        if let accountName = transaction.account?.wrappedName, !accountName.isEmpty {
            return "\(time) · \(accountName)"
        }
        return time
    }

    private var amountColor: Color {
        if future {
            return Color.SubtitleText
        }
        return transaction.income ? Color.IncomeGreen : Color.PrimaryText
    }

    /// Balance corrections have no category; give them a neutral icon of
    /// their own instead of an empty swatch.
    private var tileEmoji: String {
        if transaction.adjustment { return "⚖️" }
        return transaction.category?.wrappedEmoji ?? ""
    }

    private var tileColour: String {
        if transaction.adjustment { return "#8E8E93" }
        return transaction.category?.wrappedColour ?? "#FFFFFF"
    }

    private var discountText: String? {
        guard transaction.discount > 0 else { return nil }
        return Money.format(transaction.discount,
                            currencyCode: transaction.account?.resolvedCurrencyCode ?? currency,
                            showsCents: showCents, locale: .appLocale)
    }

    @ViewBuilder
    private var badges: some View {
        let pending = transaction.isPendingReimbursement
        let showsDiscount = discountText != nil

        if transaction.adjustment || transaction.reimbursable || showsDiscount {
            HStack(spacing: 4) {
                if transaction.adjustment {
                    badge(String.appLocalized("Balance Adjustment"), tint: Color.SubtitleText)
                }
                if transaction.reimbursable {
                    badge(String.appLocalized(pending ? "Pending" : "Reimbursed"),
                          tint: pending ? Color.orange : Color.IncomeGreen)
                }
                if let discountText {
                    badge(String.appFormatted("Discount %@", discountText),
                          tint: Color.SubtitleText)
                }
            }
        }
    }

    private func badge(_ text: String, tint: Color) -> some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(tint.opacity(0.14), in: Capsule())
    }

    var body: some View {
        HStack(spacing: SBSpace.small) {
            EmojiLogView(
                emoji: tileEmoji,
                colour: tileColour,
                future: future
            )
            .fixedSize(horizontal: true, vertical: true)
            .overlay(alignment: .bottomTrailing) {
                if transaction.recurringType > 0 {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color.SubtitleText)
                        .padding(3)
                        .background(Color.SecondaryBackground, in: RoundedRectangle(cornerRadius: SBRadius.pill))
                        .offset(x: 5, y: 5)
                        .accessibilityHidden(true)
                }
            }

            if dynamicTypeSize.isAccessibilitySize {
                // At accessibility sizes the note and the amount each need a
                // full line; side by side they both truncate.
                VStack(alignment: .leading, spacing: 4) {
                    nameAndTime
                    amountLabel
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            } else {
                nameAndTime
                    .frame(maxWidth: .infinity, alignment: .leading)
                amountLabel
            }
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }

    private var nameAndTime: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(transaction.wrappedNote.isEmpty
                 ? (transaction.category?.wrappedName ?? String.appLocalized("Unknown"))
                 : transaction.wrappedNote)
                .font(.body)
                .foregroundStyle(future ? Color.SubtitleText : Color.PrimaryText)
                .lineLimit(2)

            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(Color.SubtitleText)
                .lineLimit(1)

            badges
        }
    }

    private var amountLabel: some View {
        Text(amountText)
            .font(.body.monospacedDigit())
            .foregroundStyle(amountColor)
            .lineLimit(1)
            .layoutPriority(1)
            .accessibilityLabel(amountText)
    }
}

// MARK: - Day header

extension LogTransactionList where Header == EmptyView {
    init(entries: [LogEntry], future: Bool = false, upcoming: [TransactionModel] = []) {
        self.init(entries: entries, future: future, upcoming: upcoming) { EmptyView() }
    }
}
