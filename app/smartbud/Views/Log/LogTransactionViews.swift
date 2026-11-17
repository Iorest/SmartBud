import Foundation
import SwiftData
import SwiftUI

struct SingleTransactionView: View {
    let transaction: TransactionModel
    let showCents: Bool
    let currencySymbol: String
    let currency: String
    let swapTimeLabel: Bool
    let future: Bool
    let showExpenseOrIncomeSign: Bool

    @State var refreshID = UUID()

    @Environment(TransactionViewModel.self) var transactionVM
    @Environment(OverallTransactionManager.self) var transactionManager

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var transactionAmountString: String {
        Money.format(transaction.amount,
                     currencyCode: transaction.account?.resolvedCurrencyCode ?? currency,
                     showsCents: showCents)
    }

    var transactionAmountAccessibilityString: String {
        transaction.wrappedAmount.formatted(.number.precision(.fractionLength(2)))
    }

    private var nameAndTime: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(transaction.wrappedNote)
                .font(.body.weight(.medium))
                .foregroundStyle(future ? Color.SubtitleText : Color.PrimaryText)
                .lineLimit(2)

            Text(getSubtitle())
                .font(.subheadline.weight(.medium))
                .foregroundStyle(future ? Color.EvenLighterText : Color.SubtitleText)
                .lineLimit(1)
        }
    }

    /// Income and refunds both bring money in; only expenses take it out.
    private var incoming: Bool { transaction.income || transaction.isRefund }

    private var amountLabel: some View {
        Text(showExpenseOrIncomeSign
             ? "\(incoming ? "+" : "-")\(transactionAmountString)"
             : transactionAmountString)
            .font(.title3.weight(.medium).monospacedDigit())
            .foregroundStyle(incoming
                             ? (future ? Color.SubtitleText : Color.IncomeGreen)
                             : (future ? Color.SubtitleText : Color.PrimaryText))
            .minimumScaleFactor(0.6)
            .lineLimit(1)
            .layoutPriority(1)
    }

    var body: some View {
        HStack(spacing: 12) {
            EmojiLogView(emoji: (transaction.category?.wrappedEmoji ?? ""),
                         colour: (transaction.category?.wrappedColour ?? "#FFFFFF"), future: future)
                .fixedSize(horizontal: true, vertical: true)
                .overlay(alignment: .bottomTrailing) {
                    if transaction.recurringType > 0 {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color.DarkIcon)
                            .padding(3)
                            .background(
                                Color.SecondaryBackground,
                                in: RoundedRectangle(cornerRadius: SBRadius.pill)
                            )
                            .offset(x: 5, y: 5)
                    }
                }

            if dynamicTypeSize.isAccessibilitySize {
                // Large text: amount gets its own row under the note so
                // neither the note nor the time truncates.
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
        .id(refreshID)
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .contentShape(RoundedRectangle(cornerRadius: SBRadius.chip))
        .onTapGesture {
            transactionManager.toEdit = transaction
        }
        .contextMenu {
            if transaction.recurringType > 0 {
                Button {
                    transactionVM.stopRecurring(transaction)
                } label: {
                    Label(String.appLocalized("Stop Recurring"), systemImage: "xmark")
                }
            }

            Button {
                transactionManager.toEdit = transaction
            } label: {
                Label(String.appLocalized("Edit"), systemImage: "pencil")
            }

            if !(future && transaction.wrappedDate < Date.now && transaction.recurringType > 0) {
                Button {
                    transactionManager.toDelete = transaction
                    transactionManager.future = future
                    transactionManager.showPopup = true

                } label: {
                    Label(String.appLocalized("Delete"), systemImage: "xmark.bin")
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String.appFormatted(
            "%@, %@%@, Category: %@, at %@",
            transaction.wrappedNote,
            currencySymbol,
            transactionAmountAccessibilityString,
            transaction.category?.wrappedName ?? String.appLocalized("Unknown"),
            timeConverterAccessibilityLabel(date: transaction.wrappedDate)
        ))
    }

    func getSubtitle() -> String {
        if future {
            if transaction.wrappedDate > Date.now {
                return dateFormatter(date: transaction.wrappedDate)
            } else {
                return dateFormatter(date: transaction.nextTransactionDate)
            }
        } else {
            if swapTimeLabel {
                return transaction.wrappedCategoryName
            } else {
                let formatter = DateFormatter()
                formatter.locale = Locale.appLocale
                formatter.dateFormat = "h:mm a"

                return formatter.string(from: transaction.wrappedDate)
            }
        }
    }
}

func dateFormatter(date: Date) -> String {
    let dateFormatter = DateFormatter()
    dateFormatter.locale = Locale.appLocale

    dateFormatter.setLocalizedDateFormatFromTemplate("MMMd")
    return dateFormatter.string(from: date).uppercased()
}

struct EmojiLogView: View {
    let emoji: String
    let colour: String
    let future: Bool
    let huge: Bool

    var body: some View {
        ZStack {
            if future {
                RoundedRectangle(cornerRadius: SBRadius.chip, style: .continuous)
                    .stroke(Color(hex: colour).opacity(0.73), lineWidth: 2)
                    .foregroundStyle(.clear)
            } else {
                RoundedRectangle(cornerRadius: huge ? 20 : SBRadius.chip, style: .continuous)
                    .fill(blend(over: Color(hex: colour), withAlpha: 0.73))
//
            }

            Text(emoji)
                .font(.system(huge ? .title : .title3))
                // future ? .caption :

                .padding(8)
        }
        .opacity(future ? 0.6 : 1)
    }

    init(emoji: String, colour: String, future: Bool, huge: Bool = false) {
        self.emoji = emoji
        self.colour = colour
        self.future = future
        self.huge = huge
    }
}
