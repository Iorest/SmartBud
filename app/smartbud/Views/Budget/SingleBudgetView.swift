import Foundation
import SwiftUI
import SwiftData

struct SingleBudgetView: View {
    let budget: BudgetModel

    @Environment(BudgetViewModel.self) var budgetVM

    @Binding var toDelete: BudgetModel?
    @Binding var toEdit: BudgetModel?

    var totalSpent: Double {
        budgetAmount - budgetVM.leftover(budget)
    }

    var budgetRows: Bool

    var budgetAmount: Double {
        return budget.amount
    }

    /// "left" / "over" before the period label.
    private var remainingStatus: String {
        budgetAmount >= totalSpent ? String.appLocalized("left") : String.appLocalized("over")
    }

    var budgetType: String {
        String.appLocalized(BudgetPeriod.labelKey(for: budget.type))
    }

    var timeLeft: String {
        let calendar = Calendar.current

        if budgetRows {
            if budget.type == 1 {
                let components = calendar.dateComponents([.hour], from: budget.wrappedDate, to: Date.now)

                return String.appFormatted("%lldh left", 24 - (components.hour ?? 0))
            } else if budget.type == 2 {
                let components = calendar.dateComponents([.day], from: budget.wrappedDate, to: Date.now)

                return String.appFormatted("%lldd left", 7 - (components.day ?? 0))
            } else {
                let components1 = calendar.dateComponents([.day], from: budget.wrappedDate, to: budget.endDate)
                let numberOfDays = components1.day ?? 0

                let components2 = calendar.dateComponents([.day], from: budget.wrappedDate, to: Date.now)
                let numberOfDaysPast = components2.day ?? 0

                let daysLeftNumber = Int(numberOfDays - numberOfDaysPast)
                return String.appFormatted("%lldd left", daysLeftNumber)
            }
        } else {
            if budget.type == 1 {
                let components = calendar.dateComponents([.hour], from: budget.wrappedDate, to: Date.now)

                return String.appFormatted("^[%lld hours left](inflect: true)", 24 - (components.hour ?? 0))
            } else if budget.type == 2 {
                let components = calendar.dateComponents([.day], from: budget.wrappedDate, to: Date.now)

                return String.appFormatted("^[%lld days left](inflect: true)", 7 - (components.day ?? 0))
            } else {
                let components1 = calendar.dateComponents([.day], from: budget.wrappedDate, to: budget.endDate)
                let numberOfDays = components1.day ?? 0

                let components2 = calendar.dateComponents([.day], from: budget.wrappedDate, to: Date.now)
                let numberOfDaysPast = components2.day ?? 0

                let daysLeftNumber = Int(numberOfDays - numberOfDaysPast)
                return String.appFormatted("%lld days left", daysLeftNumber)
            }
        }
    }

    @AppStorage("currency", store: .appGroup) var currency: String = Locale.current.currency?.identifier ?? "USD"
    var currencySymbol: String {
        return Locale.appCurrencySymbol(forCurrencyCode: currency)
    }

    var difference: Double {
        return abs(budgetAmount - totalSpent)
    }

    var percentString1: String {
        return "\(Int(round(Money.spendFraction(totalSpent, of: budgetAmount) * 100)))%"
    }

    /// Share of the period still ahead, measured from the *current* period's
    /// start (the stored one only rolls when the budget screen opens).
    var remainingFraction: Double {
        let calendar = Calendar.current
        let start = BudgetRollover.roll(startDate: budget.wrappedDate,
                                        type: budget.type) ?? budget.wrappedDate
        let end = BudgetPeriod.endDate(from: start, type: budget.type)
        let numberOfDays = calendar.dateComponents([.day], from: start, to: end).day ?? 0
        let numberOfDaysPast = (calendar.dateComponents([.day], from: start, to: .now).day ?? 0) + 1
        guard numberOfDays > 0 else { return 0 }
        return Double(numberOfDays - numberOfDaysPast) / Double(numberOfDays)
    }

    // swipe to delete
    @State private var offset: CGFloat = 0
    @State private var deleted: Bool = false

    /// Measured card width; the swipe thresholds are relative to the card, so
    /// a two-column iPad layout and a phone row behave the same.
    @State private var cardWidth: CGFloat = 0

    private var swipeWidth: CGFloat { max(cardWidth, 120) }

    var deletePopup: Bool {
        return abs(offset) > swipeWidth * 0.15
    }

    var deleteConfirm: Bool {
        return abs(offset) > swipeWidth * 0.50
    }

    @GestureState var isDragging = false

    @State private var lightHaptic = 0
    @State private var heavyHaptic = 0

    init(budget: BudgetModel, toDelete: Binding<BudgetModel?>?, toEdit: Binding<BudgetModel?>?, budgetRows: Bool) {
        self.budget = budget
        self.budgetRows = budgetRows
        _toDelete = toDelete ?? Binding.constant(nil)
        _toEdit = toEdit ?? Binding.constant(nil)
    }
}

extension SingleBudgetView {

    var body: some View {
        Group {
            if budgetRows {
                ZStack(alignment: .trailing) {
                    Image(systemName: "xmark")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(deleteConfirm ? Color.AlertRed : Color.SubtitleText)
                        .padding(5)
                        .systemTintedChip(deleteConfirm ? Color.AlertRed : Color.SubtitleText, in: Circle())
                        .scaleEffect(deleteConfirm ? 1.1 : 1)
                        .contentShape(Circle())
                        .opacity(deleted ? 0 : 1)
                        .padding(.horizontal, 10)
                        .offset(x: 80)
                        .offset(x: max(-80, offset))

                    HStack {
                        HStack(spacing: 10) {
                            ZStack {
                                RoundedRectangle(cornerRadius: SBRadius.chip, style: .continuous)
                                    .fill(.white)

                                RoundedRectangle(cornerRadius: SBRadius.chip, style: .continuous)
                                    .fill(Color(hex: budget.wrappedColour).opacity(0.3))
                            }
                            .frame(width: 40, height: 40)
                            .overlay {
                                Text(budget.wrappedEmoji)
                                    .font(.system(.title3))
                            }

                            VStack(alignment: .leading, spacing: -0.5) {
                                Text(budget.wrappedName)
                                    .font(.body.weight(.semibold))
                                    .lineLimit(1)
                                    .foregroundStyle(Color.PrimaryText)

                                Text(String.appFormatted("%@ • %@ spent", timeLeft, percentString1))
                                    .font(.footnote.weight(.medium))
                                    .lineLimit(1)
                                    .foregroundStyle(Color.SubtitleText)
                            }
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: -4) {
                            BudgetDollarView(amount: difference, red: totalSpent >= budgetAmount, scale: 1)

                            Text("\(remainingStatus) \(budgetType)")
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(Color.SubtitleText)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier(
                            AccessibilityID.budgetRemaining(budget.wrappedName))
                    }
                    .padding(10)
                    .systemCard(in: RoundedRectangle(cornerRadius: SBRadius.card, style: .continuous))
                    .contentShape(RoundedRectangle(cornerRadius: SBRadius.card))
                    .contextMenu {
                        Button {
                            toEdit = budget

                        } label: {
                            Label(String.appLocalized("Edit"), systemImage: "pencil")
                        }
                        Button {
                            toDelete = budget
                        } label: {
                            Label(String.appLocalized("Delete"), systemImage: "xmark.bin")
                        }
                    }
                    .offset(x: offset)
                }
                .padding(.horizontal, 30)
                .onGeometryChange(for: CGFloat.self) { proxy in
                    proxy.size.width
                } action: { width in
                    cardWidth = width
                }
                .onChange(of: deletePopup) { _, _ in
                    if deletePopup {
                        lightHaptic &+= 1
                    }
                }
                .onChange(of: deleteConfirm) { _, _ in
                    if deleteConfirm {
                        heavyHaptic &+= 1
                    }
                }
                .animation(.default, value: deletePopup)
                .simultaneousGesture(
                    DragGesture()
                        .updating($isDragging, body: { _, state, _ in
                            state = true
                        })
                        .onChanged { value in
                            if value.translation.width < 0 {
                                offset = value.translation.width
                            }
                        }.onEnded { _ in
                            if deleteConfirm {
                                // A full swipe never deletes directly; it
                                // reuses the same confirmation as a short one.
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    offset = 0
                                }
                                toDelete = budget
                            } else if deletePopup {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    offset = 0
                                }

                                toDelete = budget
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
            } else {
                VStack {
                    HStack {
                        VStack(alignment: .leading, spacing: 0.5) {
                            HStack(spacing: 4) {
                                Text(budget.wrappedEmoji)
                                    .font(.caption)

                                Text(budget.wrappedName)
                                    .font(.subheadline.weight(.semibold))
                                    .lineLimit(1)
                                    .foregroundStyle(Color.PrimaryText)
                            }

                            Text(timeLeft)
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(Color.SubtitleText)
                                .multilineTextAlignment(.leading)
                        }

                        Spacer()
                    }
                    .frame(maxWidth: .infinity)

                    Spacer(minLength: 30)

                    // Main figure is the remaining amount; the status word
                    // sits beside it so the number is never ambiguous.
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(remainingStatus)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Color.SubtitleText)

                        BudgetDollarView(amount: difference, red: totalSpent >= budgetAmount, scale: 2)

                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier(
                        AccessibilityID.budgetRemaining(budget.wrappedName))

                    Text(String.appFormatted("%@ • %@ spent", budgetType, percentString1))
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(totalSpent >= budgetAmount ? Color.AlertRed : Color.SubtitleText)
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    GeometryReader { proxy in
                        ProgressView(value: min(max(totalSpent / max(budgetAmount, 1), 0), 1))
                            .tint(totalSpent >= budgetAmount
                                  ? Color.AlertRed
                                  : Color(hex: budget.category?.wrappedColour ?? "#007AFF"))
                            .frame(maxWidth: .infinity)
                        .overlay(alignment: .topLeading) {
                            if budget
                                .type != 1 && totalSpent < budgetAmount
                                    && remainingFraction > 0.05 && remainingFraction < 0.95 {
                                // The marker shows how much of the budget
                                // *should* be spent by now, so it moves right
                                // as the period elapses. Drawing the remaining
                                // fraction put it at 93% on day two.
                                let elapsed = 1 - remainingFraction
                                RoundedTriangle(cornerRadius: 1.3)
                                    .fill((remainingFraction * budgetAmount) <= (budgetAmount - totalSpent)
                                          ? Color.DarkBackground : Color.AlertRed)
                                    .frame(width: 14, height: 6.5)
                                    .offset(x: (elapsed * proxy.size.width) - 7, y: -3.5)
                            }
                        }
                    }
                    .frame(height: 17.5)
                }
                .padding(15)
                .frame(maxWidth: .infinity)
                .systemCard(in: RoundedRectangle(cornerRadius: SBRadius.card, style: .continuous))
                .contentShape(RoundedRectangle(cornerRadius: SBRadius.card))
                .contextMenu {
                    Button {
                        toEdit = budget

                    } label: {
                        Label(String.appLocalized("Edit"), systemImage: "pencil")
                    }
                    Button {
                        toDelete = budget
                    } label: {
                        Label(String.appLocalized("Delete"), systemImage: "xmark.bin")
                    }
                }
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: lightHaptic)
        .sensoryFeedback(.impact(weight: .heavy), trigger: heavyHaptic)
    }
}
