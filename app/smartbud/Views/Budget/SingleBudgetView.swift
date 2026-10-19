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

    var width: CGFloat {
        ((ScreenSize.width - 75) / 2) - 30
    }

    var rowWidth: CGFloat {
        (ScreenSize.width - 80) / 2
    }

    var budgetAmount: Double {
        return budget.amount
    }

    var budgetType: String {
        switch budget.type {
        case 1:
            return String.appLocalized("today")
        case 2:
            return String.appLocalized("this week")
        case 3:
            return String.appLocalized("this month")
        case 4:
            return String.appLocalized("this year")
        default:
            return String.appLocalized("this week")
        }
    }

    var timeLeft: String {
        let calendar = Calendar.current

        if budgetRows {
            if budget.type == 1 {
                let components = calendar.dateComponents([.hour], from: budget.wrappedDate, to: Date.now)

                return String(localized: "\(24 - components.hour!)h left")
            } else if budget.type == 2 {
                let components = calendar.dateComponents([.day], from: budget.wrappedDate, to: Date.now)

                return String(localized: "\(7 - (components.day ?? 0))d left")
            } else {
                let components1 = calendar.dateComponents([.day], from: budget.wrappedDate, to: budget.endDate)
                let numberOfDays = components1.day ?? 0

                let components2 = calendar.dateComponents([.day], from: budget.wrappedDate, to: Date.now)
                let numberOfDaysPast = components2.day ?? 0

                let daysLeftNumber = Int(numberOfDays - numberOfDaysPast)
                return String(localized: "\(daysLeftNumber)d left")
            }
        } else {
            if budget.type == 1 {
                let components = calendar.dateComponents([.hour], from: budget.wrappedDate, to: Date.now)

                return String(localized: "^[\(24 - (components.hour ?? 0)) hours left](inflect: true)")
            } else if budget.type == 2 {
                let components = calendar.dateComponents([.day], from: budget.wrappedDate, to: Date.now)

                return String(localized: "^[\(7 - (components.day ?? 0)) days left](inflect: true)")
            } else {
                let components1 = calendar.dateComponents([.day], from: budget.wrappedDate, to: budget.endDate)
                let numberOfDays = components1.day ?? 0

                let components2 = calendar.dateComponents([.day], from: budget.wrappedDate, to: Date.now)
                let numberOfDaysPast = components2.day ?? 0

                let daysLeftNumber = Int(numberOfDays - numberOfDaysPast)
                return String(localized: "\(daysLeftNumber) days left")
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

    var percentString: String {
        return "\(Int(round(100 - (totalSpent / budgetAmount) * 100)))%"
    }

    var percentString1: String {
        return "\(Int(round((totalSpent / budgetAmount) * 100)))%"
    }

    var targetPercent: Double {
        let calendar = Calendar.current

        let components1 = calendar.dateComponents([.day], from: budget.wrappedDate, to: budget.endDate)
        let numberOfDays = components1.day ?? 0

        let components2 = calendar.dateComponents([.day], from: budget.wrappedDate, to: Date.now)
        let numberOfDaysPast = components2.day ?? 0 + 1

        return Double(numberOfDays - numberOfDaysPast) / Double(numberOfDays)
    }

    @Environment(\.colorScheme) var colorScheme

    // swipe to delete
    @State private var offset: CGFloat = 0
    @State private var deleted: Bool = false

    var deletePopup: Bool {
        return abs(offset) > ScreenSize.width * 0.15
    }

    var deleteConfirm: Bool {
        return abs(offset) > ScreenSize.width * 0.50
    }

    @GestureState var isDragging = false

    @State private var lightHaptic = 0
    @State private var heavyHaptic = 0

    var body: some View {
        Group {
            if budgetRows {
                ZStack(alignment: .trailing) {
                    Image(systemName: "xmark")
                        .font(.system(.footnote, design: .rounded).weight(.bold))
//                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(deleteConfirm ? Color.AlertRed : Color.SubtitleText)
                        .padding(5)
                        .tintedGlassChip(deleteConfirm ? Color.AlertRed : Color.SubtitleText, in: Circle())
                        .scaleEffect(deleteConfirm ? 1.1 : 1)
                        .contentShape(Circle())
                        .opacity(deleted ? 0 : 1)
                        .padding(.horizontal, 10)
                        .offset(x: 80)
                        .offset(x: max(-80, offset))

                    HStack {
                        HStack(spacing: 10) {
                            ZStack {
                                RoundedRectangle(cornerRadius: GlassRadius.chip, style: .continuous)
                                    .fill(.white)

                                RoundedRectangle(cornerRadius: GlassRadius.chip, style: .continuous)
                                    .fill(Color(hex: budget.wrappedColour).opacity(0.3))
                            }
                            .frame(width: 40, height: 40)
                            .overlay {
                                Text(budget.wrappedEmoji)
                                    .font(.system(size: 20))
                            }

                            VStack(alignment: .leading, spacing: -0.5) {
                                Text(budget.wrappedName)
                                    .font(.system(.body, design: .rounded).weight(.semibold))
//                                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                                    .lineLimit(1)
                                    .foregroundStyle(Color.PrimaryText)

                                Text(String(localized: "\(timeLeft) • \(percentString1) spent"))
                                    .font(.system(.footnote, design: .rounded).weight(.medium))
//                                    .font(.system(size: 13, weight: .medium, design: .rounded))
                                    .lineLimit(1)
                                    .foregroundStyle(Color.SubtitleText)
                            }
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: -4) {
                            BudgetDollarView(amount: difference, red: totalSpent >= budgetAmount, scale: 1, size: 80)

                            Text("\(budgetAmount >= totalSpent ? String.appLocalized("left") : String.appLocalized("over")) \(budgetType)")
                                .font(.system(.caption2, design: .rounded).weight(.medium))
                                .foregroundStyle(Color.SubtitleText)
                        }
                    }
                    .padding(10)
                    .glassCard(in: RoundedRectangle(cornerRadius: GlassRadius.card, style: .continuous))
                    .contentShape(RoundedRectangle(cornerRadius: GlassRadius.card))
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
                                deleted = true
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    offset -= ScreenSize.width
                                }

                                Task { @MainActor in
                                    try? await Task.sleep(for: .milliseconds(400))
                                    withAnimation {
                                        budgetVM.delete(budget)
                                    }
                                }

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
                                    .font(.system(.caption, design: .rounded))
//                                    .font(.system(size: 11.5))

                                Text(budget.wrappedName)
                                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
//                                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                                    .lineLimit(1)
                                    .foregroundStyle(Color.PrimaryText)
                            }

                            Text(timeLeft)
                                .font(.system(.footnote, design: .rounded).weight(.semibold))
//                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(Color.SubtitleText)
                                .multilineTextAlignment(.leading)
                        }

                        Spacer()
                    }
                    .frame(maxWidth: .infinity)

                    Spacer(minLength: 30)

                    HStack {
                        VStack(alignment: .leading, spacing: -2) {
                            if totalSpent < budgetAmount {
                                Text(String(localized: "\(percentString1) SPENT"))
                                    .font(.system(.caption2, design: .rounded).weight(.semibold))
//                                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                                    .lineLimit(1)
                                    .foregroundStyle(totalSpent / budgetAmount > 1 ? Color.AlertRed : Color.IncomeGreen)
                                    .padding(.bottom, 5)
                            }

                            BudgetDollarView(amount: difference, red: totalSpent >= budgetAmount, scale: 2, size: width - 40)

                            Text("\(budgetAmount >= totalSpent ? String.appLocalized("left") : String.appLocalized("over")) \(budgetType)")
                                .font(.system(.footnote, design: .rounded).weight(.medium))
                                .foregroundStyle(Color.SubtitleText)
                                .minimumScaleFactor(0.7)
                                .lineLimit(1)
                        }

                        Spacer()
                    }
                    .frame(maxWidth: .infinity)

                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: GlassRadius.input, style: .continuous)
                                .fill(Color.SecondaryBackground)
                                .frame(width: proxy.size.width)

                            if totalSpent / budgetAmount < 0.98 {
                                if let category = budget.category {
                                    AnimatedHorizontalBarGraphBudget(category: category)
                                        .frame(width: proxy.size.width * (1 - totalSpent / budgetAmount))
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .overlay(alignment: .topLeading) {
                            if budget.type != 1 && totalSpent < budgetAmount && targetPercent > 0 && targetPercent < 0.95 {
                                RoundedTriangle(cornerRadius: 1.3)
                                    .fill((targetPercent * budgetAmount) <= (budgetAmount - totalSpent) ? Color.DarkBackground : Color.AlertRed)
                                    .frame(width: 14, height: 6.5)
                                    .offset(x: (targetPercent * proxy.size.width) - 7, y: -3.5)
                            }
                        }
                    }
                    .frame(height: 17.5)
                }
                .padding(15)
                .frame(width: width + 30)
                .glassCard(in: RoundedRectangle(cornerRadius: GlassRadius.card, style: .continuous))
                .contentShape(RoundedRectangle(cornerRadius: GlassRadius.card))
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

    init(budget: BudgetModel, toDelete: Binding<BudgetModel?>?, toEdit: Binding<BudgetModel?>?, budgetRows: Bool) {
        self.budget = budget
        self.budgetRows = budgetRows
        _toDelete = toDelete ?? Binding.constant(nil)
        _toEdit = toEdit ?? Binding.constant(nil)
    }
}

