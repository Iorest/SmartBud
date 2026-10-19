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
//    @State private var toDelete: Transaction?
//    @State var deleteMode = false
//
//    // edit mode
//    @State private var toEdit: Transaction?

    @State private var offset: CGFloat = 0
    @State private var deleted: Bool = false
    var deletePopup: Bool {
        return abs(offset) > ScreenSize.width * 0.2
    }

    var deleteConfirm: Bool {
        return abs(offset) > ScreenSize.width * 0.42
    }

    @GestureState var isDragging = false

    @State private var lightHaptic = 0
    @State private var mediumHaptic = 0

    var imageSize: Double {
        let scale = min(1.5, 1 + (abs(offset + 40) / 100))
        return scale * 10 as Double
    }

    var imageScale: Double {
        return min(1, 1 + (abs(Double(offset) + 40) / 100))
    }

    var transactionAmountString: String {
        let numberFormatter = NumberFormatter()
        numberFormatter.locale = Locale.appLocale
        numberFormatter.numberStyle = .currency
        numberFormatter.currencyCode = currency

        if showCents {
            numberFormatter.maximumFractionDigits = 2
        } else {
            numberFormatter.maximumFractionDigits = 0
        }

        return numberFormatter.string(from: NSNumber(value: transaction.amount)) ?? "$0"
    }

    var transactionAmountAccessibilityString: String {
        transaction.wrappedAmount.formatted(.number.precision(.fractionLength(2)))
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            Image(systemName: "xmark")
//                .font(.system(size: 13, weight: .bold))
                .font(.system(.caption, design: .rounded).weight(.bold))
                .dynamicTypeSize(...DynamicTypeSize.xLarge)
                .foregroundStyle(deleteConfirm ? Color.AlertRed : Color.SubtitleText)
                .padding(5)
                .background(deleteConfirm ? Color.AlertRed.opacity(0.23) : Color.SecondaryBackground, in: Circle())
//                .scaleEffect(imageScale)
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
                                .background(Color.SecondaryBackground, in: RoundedRectangle(cornerRadius: GlassRadius.pill))
                                .offset(x: 5, y: 5)
                        }
                    }

                VStack(alignment: .leading, spacing: 2) {
                    Text(transaction.wrappedNote)
                        .font(.system(.body, design: .rounded).weight(.medium))
                        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                        .foregroundStyle(future ? Color.SubtitleText : Color.PrimaryText)
                        .lineLimit(1)

                    Text(getSubtitle())
                        .font(.system(.subheadline, design: .rounded).weight(.medium))
                        .dynamicTypeSize(...DynamicTypeSize.xxLarge)
                        .foregroundStyle(future ? Color.EvenLighterText : Color.SubtitleText)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if transaction.income {
                    Text(showExpenseOrIncomeSign ? "+\(transactionAmountString)" : transactionAmountString)
                        .font(.system(.title3, design: .rounded).weight(.medium))
                        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                        .foregroundStyle(future ? Color.SubtitleText : Color.IncomeGreen)
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                        .layoutPriority(1)

                } else {
                    Text(showExpenseOrIncomeSign ? "-\(transactionAmountString)" : transactionAmountString)
                        .font(.system(.title3, design: .rounded).weight(.medium))
                        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                        .foregroundStyle(future ? Color.SubtitleText : Color.PrimaryText)
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                        .layoutPriority(1)
                }
            }
            .id(refreshID)
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .contentShape(RoundedRectangle(cornerRadius: GlassRadius.chip))
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
            .accessibilityLabel(String(localized: "\(transaction.wrappedNote), \(currencySymbol)\(transactionAmountAccessibilityString), Transaction Category: \(transaction.category?.wrappedName ?? String.appLocalized("Unknown")), Transaction made at \(timeConverterAccessibilityLabel(date: transaction.wrappedDate))"))
        }
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
                            offset -= ScreenSize.width
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
//                withAnimation(.easeInOut(duration: 0.3)){
//                   offset = 0
//                }
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

    dateFormatter.dateFormat = "d MMM"
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
                RoundedRectangle(cornerRadius: GlassRadius.chip, style: .continuous)
                    .stroke(Color(hex: colour).opacity(0.73), lineWidth: 2)
                    .foregroundStyle(.clear)
            } else {
                RoundedRectangle(cornerRadius: huge ? 20 : GlassRadius.chip, style: .continuous)
                    .fill(blend(over: Color(hex: colour), withAlpha: 0.73))
//                RoundedRectangle(cornerRadius: GlassRadius.chip, style: .continuous)
//                    .fill(Color.white)
//
//                RoundedRectangle(cornerRadius: GlassRadius.chip, style: .continuous)
//                    .fill(Color(hex: colour).opacity(0.73))
            }

            Text(emoji)
                .font(.system(huge ? .title : .title3))
                // future ? .caption :
                .dynamicTypeSize(...DynamicTypeSize.xxLarge)
                .padding(8)
//                .font(.system(size: huge ? 45 : future ? 16: 20))
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
                Text(stopRecurring ? String.appLocalized("Stop Recurring?") : String(localized: "Delete '\(unwrappedToDelete.wrappedNote)'?"))
                    .font(.system(.title2, design: .rounded).weight(.medium))
                    .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
//                    .font(.system(size: 25, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.PrimaryText)
                    .accessibilityLabel(String(localized: "Delete \(unwrappedToDelete.wrappedNote) transaction confirmation. You can undo right after deleting."))

                Text(String.appLocalized(stopRecurring ? "The transaction will no longer be automatically logged." : "You can undo right after deleting."))
                    .font(.system(.title3, design: .rounded).weight(.medium))
                    .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
//                    .font(.system(size: 20, weight: .medium, design: .rounded))
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
            //            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: GlassRadius.card, style: .continuous))
            .glassCard(in: RoundedRectangle(cornerRadius: GlassRadius.card, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: GlassRadius.card).stroke(systemColorScheme == .dark ? Color.gray.opacity(0.1) : Color.clear, lineWidth: 1.3))
//            .offset(y: offset)
//            .gesture(
//                DragGesture()
//                    .onChanged { gesture in
//                        if gesture.translation.height < 0 {
//                            offset = gesture.translation.height / 3
//                        } else {
//                            offset = gesture.translation.height
//                        }
//                    }
//                    .onEnded { value in
//                        if value.translation.height > 20 {
//                            dismiss()
//                        } else {
//                            withAnimation {
//                                offset = 0
//                            }
//
//                        }
//                    }
//            )
            .padding(.horizontal, 17)
            .padding(.bottom, bottomEdge == 0 ? 13 : bottomEdge)
        }
    }
}

