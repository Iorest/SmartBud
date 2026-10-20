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

    // delete mode
//
//    // edit mode

    @State private var offset: CGFloat = 0
    @State private var deleted: Bool = false
    /// Row width, not the display width: on iPad/Mac a row is much narrower
    /// than the window, so screen-based thresholds made a short swipe
    /// trigger delete.
    @State private var rowWidth: CGFloat = 0

    private var gestureWidth: CGFloat { rowWidth > 0 ? rowWidth : 375 }

    var deletePopup: Bool {
        return abs(offset) > gestureWidth * 0.2
    }

    var deleteConfirm: Bool {
        return abs(offset) > gestureWidth * 0.42
    }

    @GestureState var isDragging = false

    @State private var lightHaptic = 0
    @State private var mediumHaptic = 0
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var transactionAmountString: String {
        Money.format(transaction.amount, currencyCode: currency, showsCents: showCents)
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

    private var amountLabel: some View {
        Text(showExpenseOrIncomeSign
             ? "\(transaction.income ? "+" : "-")\(transactionAmountString)"
             : transactionAmountString)
            .font(.title3.weight(.medium).monospacedDigit())
            .foregroundStyle(transaction.income
                             ? (future ? Color.SubtitleText : Color.IncomeGreen)
                             : (future ? Color.SubtitleText : Color.PrimaryText))
            .minimumScaleFactor(0.6)
            .lineLimit(1)
            .layoutPriority(1)
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            Image(systemName: "xmark")
                .font(.caption.weight(.bold))

                .foregroundStyle(deleteConfirm ? Color.AlertRed : Color.SubtitleText)
                .padding(5)
                .background(deleteConfirm ? Color.AlertRed.opacity(0.23) : Color.SecondaryBackground, in: Circle())
                .scaleEffect(deleteConfirm ? 1.1 : 1)
                .contentShape(Circle())
                .opacity(deleted ? 0 : 1)
                .padding(.horizontal, 10)
                .offset(x: 80)
                .offset(x: max(-80, offset))

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
                                .background(Color.SecondaryBackground, in: RoundedRectangle(cornerRadius: SBRadius.pill))
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

//                        toDelete = transaction
//                        deleteMode = true
                    } label: {
                        Label(String.appLocalized("Delete"), systemImage: "xmark.bin")
                    }
                }
            }
            .offset(x: offset)
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
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { rowWidth = $0 }
        .onChange(of: deletePopup) { _, _ in
            if deletePopup {
                lightHaptic &+= 1
            }
        }
        .onChange(of: deleteConfirm) { _, _ in
            if deleteConfirm {
                mediumHaptic &+= 1
            }
        }
        .animation(.easeInOut, value: deletePopup)
        .simultaneousGesture(
            DragGesture()
                .updating($isDragging, body: { _, state, _ in
                    state = true
                })
                .onChanged { value in
                    if value.translation.width < 0 {
                        withAnimation {
                            offset = value.translation.width
                        }
                    }
                }
                .onEnded { _ in
                    if deleteConfirm {
                        deleted = true
                        withAnimation(.easeInOut(duration: 0.3)) {
                            offset -= gestureWidth
                        }

                        if future, transaction.wrappedDate < Date.now, transaction.recurringType > 0 {
                            Task { @MainActor in
                                try? await Task.sleep(for: .milliseconds(400))
                                withAnimation(.easeInOut(duration: 0.5)) {
                                    transactionVM.stopRecurring(transaction)
                                }
                            }
                        } else {
                            Task { @MainActor in
                                try? await Task.sleep(for: .milliseconds(400))
                                withAnimation {
                                    transactionVM.stageDelete(transaction)
                                    transactionManager.showToast = true
                                    transactionManager.toDelete = transaction
//                                    transactionManager.future = future
//                                    transactionManager.toDelete = transaction
//                                    transactionManager.deletionType = .instant
                                }
                            }
                        }

                    } else if deletePopup {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            offset = 0
                        }

                        transactionManager.future = future
                        transactionManager.toDelete = transaction
                        transactionManager.showPopup = true
//
//                        toDelete = transaction
//                        deleteMode = true
                    } else {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            offset = 0
                        }
                    }
                }
        )
        .onChange(of: isDragging) { _, _ in
            if !isDragging && !deleted {
                withAnimation(.easeInOut(duration: 0.3)) {
                    offset = 0
                }
            }
        }
        .onChange(of: transactionManager.toDelete) { _, newValue in
            if newValue == nil {
                deleted = false
                offset = 0
//                   offset = 0
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: lightHaptic)
        .sensoryFeedback(.impact(weight: .medium), trigger: mediumHaptic)
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

struct DeleteTransactionAlert: View {
    @Environment(TransactionViewModel.self) var transactionVM
    @Environment(\.dismiss) var dismiss
    @Environment(OverallTransactionManager.self) var transactionManager

    var stopRecurring: Bool {
        if let unwrapped = transactionManager.toDelete {
            return transactionManager.future && unwrapped.wrappedDate < Date.now && unwrapped.recurringType > 0
        } else {
            return false
        }
    }

    @Environment(\.colorScheme) var systemColorScheme

    @AppStorage("bottomEdge", store: .appGroup) var bottomEdge: Double = 15

    @State private var offset: CGFloat = 0

    var body: some View {
        if let unwrappedToDelete = transactionManager.toDelete {
            VStack(alignment: .leading, spacing: 1.5) {
                Text(stopRecurring ? String.appLocalized("Stop Recurring?") : String.appFormatted("Delete '%@'?", unwrappedToDelete.wrappedNote))
                    .font(.title2.weight(.medium))

                    .foregroundStyle(Color.PrimaryText)
                    .accessibilityLabel(String.appFormatted("Delete %@ transaction confirmation. You can undo right after deleting.", unwrappedToDelete.wrappedNote))

                Text(String.appLocalized(stopRecurring ? "The transaction will no longer be automatically logged." : "You can undo right after deleting."))
                    .font(.title3.weight(.medium))

                    .foregroundStyle(Color.SubtitleText)
                    .padding(.bottom, 25)
                    .accessibilityHidden(true)

                Button {
                    transactionManager.showPopup = false

                    if stopRecurring {
                        withAnimation(.easeInOut(duration: 0.5)) {
                            transactionVM.stopRecurring(unwrappedToDelete)
                        }
                    } else {
                        withAnimation(.easeInOut(duration: 0.5)) {
                            transactionVM.stageDelete(unwrappedToDelete)
                            transactionManager.showToast = true
                        }
                    }
                } label: {
                    DeleteButton(text: String.appLocalized(stopRecurring ? "Confirm" : "Delete"), red: true)
                }
                .padding(.bottom, 8)

                Button {
                    transactionManager.showPopup = false
                } label: {
                    DeleteButton(text: String.appLocalized("Cancel"), red: false)
                }
            }
            .padding(13)
            .systemCard(in: RoundedRectangle(cornerRadius: SBRadius.card, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: SBRadius.card).stroke(systemColorScheme == .dark ? Color.gray.opacity(0.1) : Color.clear, lineWidth: 1.3))
//                DragGesture()
//                            offset = gesture.translation.height / 3
//                        } else {
//                            offset = gesture.translation.height
//                            dismiss()
//                        } else {
//                                offset = 0
//
//            )
            .padding(.horizontal, 17)
            .padding(.bottom, bottomEdge == 0 ? 13 : bottomEdge)
        }
    }
}
