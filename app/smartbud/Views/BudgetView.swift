//
//  BudgetView.swift
//  smartbud
//
//  Created by Iorest on 20/5/22.
//

import Foundation
import SwiftUI
import SwiftData

struct BudgetView: View {
    @Query private var categories: [CategoryModel]
    @Query private var budgets: [BudgetModel]
    @Query private var mainBudget: [MainBudgetModel]

    var body: some View {
        if categories.isEmpty && budgets.isEmpty && mainBudget.isEmpty {
            VStack(spacing: 5) {
                Image("category-3")
                    .resizable()
                    .frame(width: 75, height: 75)
                    .padding(.bottom, 20)

                Text("Budget Your Finances")
                    .font(.system(.title2, design: .rounded).weight(.medium))
//                    .font(.system(size: 23.5, weight: .medium, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.PrimaryText.opacity(0.8))

                Text("Link budgets to categories and set appropriate expenditure goals")
                    .font(.system(.body, design: .rounded).weight(.medium))
//                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.SubtitleText.opacity(0.7))
            }
            .padding(.horizontal, 30)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        } else {
            ActualBudgetView()
        }
    }
}

struct ActualBudgetView: View {
    @Environment(\.colorScheme) var colorScheme
    @State private var showInfo = false

    @Query(sort: [SortDescriptor(\BudgetModel.dateCreated)]) private var budgets: [BudgetModel]
    @Query private var mainBudget: [MainBudgetModel]
    @Environment(BudgetViewModel.self) var budgetVM
    @Environment(TabBarManager.self) var tabBarManager

    @State var newBudget = false

    @State private var showMenu = false

    @State private var toDelete: BudgetModel?
    @State private var toEdit: BudgetModel?

    let layout = [
        GridItem(.flexible(), spacing: 15),
        GridItem(.flexible(), spacing: 15)
    ]

    @AppStorage("budgetViewStyle", store: .appGroup) var budgetRows: Bool = false

    @Namespace var animation

    @State var date = Date.now

    var body: some View {
        NavigationStack {
            ZStack {
                AppGlassBackground()
                    .ignoresSafeArea(.all)

                VStack(spacing: 0) {
                    HStack {
                        Text("Budgets")
                            .font(.system(.title, design: .rounded).weight(.semibold))
//                            .font(.system(size: 25, weight: .semibold, design: .rounded))
                            .accessibility(addTraits: .isHeader)

                        Button {
                            newBudget = true
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(.subheadline, design: .rounded).weight(.semibold))
//                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Color.SubtitleText)
                                .padding(4)
                                .glassChip(in: Circle())
                                .contentShape(Circle())
                        }

                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 20)
                    .padding(.horizontal, 30)
                    .padding(.bottom, 20)

                    if !budgets.isEmpty || !mainBudget.isEmpty {
                        ScrollView(showsIndicators: false) {
                            VStack {
                                if let first = mainBudget.first {
                                    NavigationLink(destination: DetailedMainBudgetView(budget: first)
                                        .onAppear {
                                            withAnimation(.easeOut.speed(2)) {
                                                tabBarManager.navigationHideTab()
                                            }
                                        }
                                        .onDisappear {
                                            withAnimation(.easeOut.speed(2)) {
                                                tabBarManager.navigationShowTab()
                                            }
                                        }

                                    ) {
                                        if budgets.count == 0 {
                                            MainBudgetView(budget: first, solo: true)
                                                .padding(.horizontal, 25)
                                                .padding(.bottom, 15)
                                        } else {
                                            MainBudgetView(budget: first, solo: false)
                                                .padding(.horizontal, 25)
                                                .padding(.bottom, 15)
                                        }
                                    }
                                }

                                if budgetRows {
                                    VStack(spacing: 10) {
                                        ForEach(budgets, id: \.self) { budget in
                                            NavigationLink(destination: DetailedBudgetView(budget: budget)
                                                .onAppear {
                                                    withAnimation(.easeOut.speed(2)) {
                                                        tabBarManager.navigationHideTab()
                                                    }
                                                }
                                                .onDisappear {
                                                    withAnimation(.easeOut.speed(2)) {
                                                        tabBarManager.navigationShowTab()
                                                    }
                                                }

                                            ) {
                                                SingleBudgetView(budget: budget, toDelete: $toDelete, toEdit: $toEdit, budgetRows: budgetRows)
                                            }
                                        }
                                    }

                                } else {
                                    LazyVGrid(columns: layout, spacing: 15) {
                                        ForEach(budgets, id: \.self) { budget in
                                            NavigationLink(destination: DetailedBudgetView(budget: budget)
                                                .onAppear {
                                                    withAnimation(.easeOut.speed(2)) {
                                                        tabBarManager.navigationHideTab()
                                                    }
                                                }
                                                .onDisappear {
                                                    withAnimation(.easeOut.speed(2)) {
                                                        tabBarManager.navigationShowTab()
                                                    }
                                                }

                                            ) {
                                                SingleBudgetView(budget: budget, toDelete: $toDelete, toEdit: $toEdit, budgetRows: budgetRows)
                                            }
                                        }
                                    }
                                    .padding(.horizontal, 25)
                                    .padding(5)
                                }
                            }
                            .padding(.bottom, 70)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        VStack(spacing: 5) {
                            Spacer()
                            Text("🙈")
                                .font(.system(.largeTitle, design: .rounded))
//                                .font(.system(size: 45))
                                .padding(.bottom, 9)

                            Text("No Budgets Found")
                                .font(.system(.title2, design: .rounded).weight(.medium))
//                                .font(.system(size: 23.5, weight: .medium, design: .rounded))
                                .multilineTextAlignment(.center)
                                .foregroundStyle(Color.PrimaryText.opacity(0.8))

                            Text("Add your first budget today!")
                                .font(.system(.body, design: .rounded).weight(.medium))
//                                .font(.system(size: 18, weight: .medium, design: .rounded))
                                .multilineTextAlignment(.center)
                                .foregroundStyle(Color.SubtitleText.opacity(0.7))

                            Spacer()
                            Spacer()
                        }
                        .padding(20)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            }
            .navigationBarTitle("")
            .toolbar(.hidden, for: .navigationBar)
            .sheet(item: $toEdit, onDismiss: {
                toEdit = nil
            }) { budget in
                BrandNewBudgetView(overallBudgetCreated: !mainBudget.isEmpty, toEditBudget: budget)
            }
            .onAppear {
                budgetVM.load()
                budgetVM.updateDates()
            }
            .sheet(isPresented: $newBudget) {
                BrandNewBudgetView(overallBudgetCreated: !mainBudget.isEmpty)
            }
            .fullScreenCover(item: $toDelete, onDismiss: {
                toDelete = nil
            }) { budget in
                DeleteBudgetAlert(toDelete: budget)
            }
        }
    }
}

struct MainBudgetView: View {
    let budget: MainBudgetModel

    @Environment(BudgetViewModel.self) var budgetVM

    @State var toEdit: MainBudgetModel?
    @State var toDelete: MainBudgetModel?

    var totalSpent: Double {
        budgetAmount - budgetVM.leftoverOverall(budget)
    }

    var soloBudget: Bool

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

    @AppStorage("currency", store: .appGroup) var currency: String = Locale.current.currency?.identifier ?? "USD"
    var currencySymbol: String {
        return Locale.appCurrencySymbol(forCurrencyCode: currency)
    }

    var percentageOfDays: Double {
        let calendar = Calendar.current

        if budget.type == 1 {
            let components = calendar.dateComponents([.minute], from: budget.wrappedDate, to: Date.now)
            return Double(components.minute ?? 0) / 1440
        }

        let components1 = calendar.dateComponents([.day], from: budget.wrappedDate, to: budget.endDate)
        let numberOfDays = components1.day ?? 0

        let components2 = calendar.dateComponents([.day], from: budget.wrappedDate, to: Date.now)
        let numberOfDaysPast = components2.day ?? 0

        return Double(numberOfDaysPast) / Double(numberOfDays)
    }

    var targetPercent: Double {
        let calendar = Calendar.current

        let components1 = calendar.dateComponents([.day], from: budget.wrappedDate, to: budget.endDate)
        let numberOfDays = components1.day ?? 0

        let components2 = calendar.dateComponents([.day], from: budget.wrappedDate, to: Date.now)
        let numberOfDaysPast = (components2.day ?? 0) + 1

        return Double(numberOfDays - numberOfDaysPast) / Double(numberOfDays)
    }

    var triangleOffset: (x: Double, y: Double) {
        var x = 0.0
        var y = -5.0

        let radius = (width / 2) - 5

        if targetPercent > 0.5 {
            let angle = (CGFloat.pi) * (1 - targetPercent)
            y += (radius - (radius * sin(angle)))
            x += (radius * cos(angle))
        } else if targetPercent < 0.5 {
            let angle = (CGFloat.pi) * targetPercent
            y += (radius - (radius * sin(angle)))
            x -= (radius * cos(angle))
        }

        return (x, y)
    }

    var triangleRotation: Double {
        if targetPercent > 0.5 {
            return ((targetPercent - 0.5) / 0.5) * 90
        } else if targetPercent < 0.5 {
            return -((0.5 - targetPercent) / 0.5) * 90
        } else {
            return 0
        }
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

    var width: CGFloat {
        if soloBudget {
            return ScreenSize.width - 90
        } else {
            return 250
        }
    }

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: 5) {
            ZStack(alignment: .bottom) {
                ZStack {
                    DonutSemicircle(percent: 1, cornerRadius: 6.5, width: soloBudget ? 35 : 25)
                        .fill(Color.SecondaryBackground)
                        .frame(width: width, height: width / 2)

                    if totalSpent / budgetAmount < 0.97 {
                        AnimatedCurvedBarGraphMainBudget(totalSpent: totalSpent, budgetTotal: budgetAmount, cornerRadius: 6.5, width: soloBudget ? 35 : 25)
                            .frame(width: width, height: width / 2)
                    }
                }
                .overlay(alignment: .top) {
                    if budget.type != 1 && totalSpent < budgetAmount && targetPercent > 0 {
                        RoundedTriangle(cornerRadius: 2)

                            .fill((targetPercent * budgetAmount) < (budgetAmount - totalSpent) ? Color.SubtitleText : Color.AlertRed)
                            .frame(width: 20, height: 10)
                            .rotationEffect(Angle(degrees: triangleRotation), anchor: .bottom)
                            .offset(x: triangleOffset.x, y: triangleOffset.y)
                    }
                }

                ArcedText(text: String(format: String.appLocalized("OVERALL SPENT: %@"), percentString1), radius: width / 2 + 8)
                    .font(.system(.footnote, design: .rounded).weight(.medium))
                    .foregroundStyle(Color.SubtitleText)
                    .frame(width: width, height: 10)

                VStack(spacing: -4) {
                    let internalWidth = soloBudget ? width - 90 : width - 60
                    BudgetDollarView(amount: difference, red: totalSpent >= budgetAmount, scale: 3, size: internalWidth)
                        .frame(width: internalWidth)

                    Text("\(budgetAmount >= totalSpent ? String.appLocalized("left") : String.appLocalized("over")) \(budgetType)")
                        .font(.system(.subheadline, design: .rounded).weight(.medium))
//                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.SubtitleText)
                }
            }

            HStack {
                if totalSpent < 1000 && budgetAmount < 1000 {
                    Text(totalSpent, format: .number.precision(.fractionLength(2)))
                        .frame(width: 60, alignment: .leading)
                    Spacer()
                    Text(budgetAmount, format: .number.precision(.fractionLength(2)))
                        .frame(width: 60, alignment: .trailing)
                } else {
                    Text("\(Int(round(totalSpent)))")
                        .frame(width: 60, alignment: .leading)
                    Spacer()
                    Text("\(Int(round(budgetAmount)))")
                        .frame(width: 60, alignment: .trailing)
                }
            }
            .font(.system(.caption2, design: .rounded).weight(.medium))
//            .font(.system(size: 10, weight: .medium, design: .rounded))
            .frame(width: width)
            .foregroundStyle(Color.SubtitleText)
        }
        .padding(.bottom)
        .frame(width: width + 30, height: soloBudget ? 230 : 200, alignment: .bottom)
        .glassCard(in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 13))
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
        .sheet(item: $toEdit, onDismiss: {
            toEdit = nil
        }) { budget in
            BrandNewBudgetView(overallBudgetCreated: true, toEditMainBudget: budget)
        }
        .fullScreenCover(item: $toDelete, onDismiss: {
            toDelete = nil
        }) { budget in
            DeleteMainBudgetAlert(toDelete: budget)
        }
    }

    init(budget: MainBudgetModel, solo: Bool) {
        self.budget = budget
        soloBudget = solo
    }
}

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

                return String(format: String.appLocalized("%dh left"), 24 - components.hour!)
            } else if budget.type == 2 {
                let components = calendar.dateComponents([.day], from: budget.wrappedDate, to: Date.now)

                return String(format: String.appLocalized("%dd left"), 7 - (components.day ?? 0))
            } else {
                let components1 = calendar.dateComponents([.day], from: budget.wrappedDate, to: budget.endDate)
                let numberOfDays = components1.day ?? 0

                let components2 = calendar.dateComponents([.day], from: budget.wrappedDate, to: Date.now)
                let numberOfDaysPast = components2.day ?? 0

                let daysLeftNumber = Int(numberOfDays - numberOfDaysPast)
                return String(format: String.appLocalized("%dd left"), daysLeftNumber
                )
            }
        } else {
            if budget.type == 1 {
                let components = calendar.dateComponents([.hour], from: budget.wrappedDate, to: Date.now)

                return String(format: String.appLocalized("%d hours left"), 24 - (components.hour ?? 0))
            } else if budget.type == 2 {
                let components = calendar.dateComponents([.day], from: budget.wrappedDate, to: Date.now)

                return String(format: String.appLocalized("%d days left"), 7 - (components.day ?? 0))
            } else {
                let components1 = calendar.dateComponents([.day], from: budget.wrappedDate, to: budget.endDate)
                let numberOfDays = components1.day ?? 0

                let components2 = calendar.dateComponents([.day], from: budget.wrappedDate, to: Date.now)
                let numberOfDaysPast = components2.day ?? 0

                let daysLeftNumber = Int(numberOfDays - numberOfDaysPast)
                return String(format: String.appLocalized("%@ days left"), "\(daysLeftNumber)")
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
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(.white)

                                RoundedRectangle(cornerRadius: 8, style: .continuous)
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

                                Text(String(format: String.appLocalized("%@ • %@ spent"), timeLeft, percentString1))
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
                    .glassCard(in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                    .contentShape(RoundedRectangle(cornerRadius: 13))
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

                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
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
                                Text(String(format: String.appLocalized("%@ SPENT"), percentString1))
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
                            RoundedRectangle(cornerRadius: 11.5, style: .continuous)
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
                .glassCard(in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                .contentShape(RoundedRectangle(cornerRadius: 13))
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

struct AnimatedBudgetBarGraph: View {
    var color: Color
    var percent: Double

    @AppStorage("animated", store: .appGroup) var animated: Bool = true
    @State var showBar: Bool = false

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(color.opacity(0.3))
                    .frame(height: proxy.size.height)

                if percent > 0 {
                    VStack(spacing: 0) {
                        Spacer(minLength: 0)

                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(color.opacity(0.73))
                            .frame(height: showBar ? nil : 0, alignment: .bottom)
                    }
                    .frame(height: proxy.size.height * percent)
                }
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now()) {
                if !animated {
                    showBar = true
                } else {
                    withAnimation(.interactiveSpring(response: 0.6, dampingFraction: 0.8, blendDuration: 0.8)) {
                        showBar = true
                    }
                }
            }
        }
    }
}

struct BudgetDollarView: View {
    @AppStorage("showCents", store: .appGroup) var showCents: Bool = true

    var amount: Double
    var red: Bool
    var scale: Int
    var size: CGFloat

    @AppStorage("currency", store: .appGroup) var currency: String = Locale.current.currency?.identifier ?? "USD"
    var currencySymbol: String {
        return Locale.appCurrencySymbol(forCurrencyCode: currency)
    }

    var dynamicTypeSizes: (symbol: Font.TextStyle, amount: Font.TextStyle) {
        if scale == 1 {
            return (.callout, .title3)
        } else if scale == 2 {
            return (.body, .title2)
        } else {
            return (.title2, .largeTitle)
        }
    }

    var body: some View {
        HStack(alignment: .lastTextBaseline, spacing: 1.3) {
            Text(currencySymbol)
                .font(.system(dynamicTypeSizes.symbol, design: .rounded).weight(.medium))
                .foregroundStyle(red ? Color.AlertRed : Color.SubtitleText)

            Text(amount, format: .number.precision(.fractionLength(showCents && amount < 100 ? 2 : 0)))
                .font(.system(dynamicTypeSizes.amount, design: .rounded).weight(.medium))
                .foregroundStyle(red ? Color.AlertRed : Color.PrimaryText)
        }
        .minimumScaleFactor(0.5)
        .lineLimit(1)
    }
}

struct DetailedBudgetDollarView: View {
    var amount: Double
    @AppStorage("showCents", store: .appGroup) var showCents: Bool = true

    @AppStorage("currency", store: .appGroup) var currency: String = Locale.current.currency?.identifier ?? "USD"
    var currencySymbol: String {
        return Locale.appCurrencySymbol(forCurrencyCode: currency)
    }

    var body: some View {
        HStack(alignment: .lastTextBaseline, spacing: 1.3) {
            Text(currencySymbol)
                .font(.system(.title2, design: .rounded).weight(.medium))
                .foregroundStyle(Color.SubtitleText)

            Text(amount, format: .number.precision(.fractionLength(showCents && amount < 100 ? 2 : 0)))
                .font(.system(.largeTitle, design: .rounded).weight(.medium))
                .foregroundStyle(Color.PrimaryText)
        }
        .minimumScaleFactor(0.5)
        .lineLimit(1)
    }
}

struct DetailedBudgetDifferenceDollarView: View {
    var amount: Double
    var red: Bool

    @AppStorage("showCents", store: .appGroup) var showCents: Bool = true

    @AppStorage("currency", store: .appGroup) var currency: String = Locale.current.currency?.identifier ?? "USD"
    var currencySymbol: String {
        return Locale.appCurrencySymbol(forCurrencyCode: currency)
    }

    var body: some View {
        HStack(alignment: .lastTextBaseline, spacing: 1.3) {
            Text(currencySymbol)
                .font(.system(.title2, design: .rounded).weight(.medium))
                .foregroundStyle(red ? Color.AlertRed : Color.SubtitleText)

            Text(amount, format: .number.precision(.fractionLength(showCents && amount < 100 ? 2 : 0)))
                .font(.system(.largeTitle, design: .rounded).weight(.medium))
                .foregroundStyle(red ? Color.AlertRed : Color.PrimaryText)
        }
        .minimumScaleFactor(0.5)
        .lineLimit(1)
    }
}

struct DeleteBudgetAlert: View {
    @Environment(BudgetViewModel.self) var budgetVM
    @Environment(\.dismiss) var dismiss
    let toDelete: BudgetModel
    @Environment(\.colorScheme) var systemColorScheme

    @AppStorage("bottomEdge", store: .appGroup) var bottomEdge: Double = 15

    @State private var offset: CGFloat = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.clear
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .onTapGesture {
                    dismiss()
                }

            VStack(alignment: .leading, spacing: 1.5) {
                Text(
                    String(
                        format: String.appLocalized("Delete the '%@' budget?"),
                        toDelete.category?.wrappedName ?? "")
                )
                    .font(.system(.title2, design: .rounded).weight(.medium))
                    .foregroundStyle(Color.PrimaryText)

                Text("This action cannot be undone.")
                    .font(.system(.title3, design: .rounded).weight(.medium))
                    .foregroundStyle(Color.SubtitleText)
                    .padding(.bottom, 25)

                Button {
                    dismiss()

                    withAnimation {
                        budgetVM.delete(toDelete)
                    }

                } label: {
                    DeleteButton(text: String.appLocalized("Delete"), red: true)
                }
                .padding(.bottom, 8)

                Button {
                    withAnimation(.easeOut(duration: 0.7)) {
                        dismiss()
                    }

                } label: {
                    DeleteButton(text: String.appLocalized("Cancel"), red: false)
                }
            }
            .padding(13)
            .glassCard(in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 13).stroke(systemColorScheme == .dark ? Color.gray.opacity(0.1) : Color.clear, lineWidth: 1.3))
            .offset(y: offset)
            .gesture(
                DragGesture()
                    .onChanged { gesture in
                        if gesture.translation.height < 0 {
                            offset = gesture.translation.height / 3
                        } else {
                            offset = gesture.translation.height
                        }
                    }
                    .onEnded { value in
                        if value.translation.height > 20 {
                            dismiss()
                        } else {
                            withAnimation {
                                offset = 0
                            }
                        }
                    }
            )
            .padding(.horizontal, 17)
            .padding(.bottom, bottomEdge == 0 ? 13 : bottomEdge)
        }
        .ignoresSafeArea(.all)
        .background(BackgroundBlurView())
    }
}

struct DeleteMainBudgetAlert: View {
    @Environment(BudgetViewModel.self) var budgetVM
    @Environment(\.dismiss) var dismiss
    let toDelete: MainBudgetModel
    @Environment(\.colorScheme) var systemColorScheme

    @AppStorage("bottomEdge", store: .appGroup) var bottomEdge: Double = 15

    @State private var offset: CGFloat = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.clear
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .onTapGesture {
                    dismiss()
                }

            VStack(alignment: .leading, spacing: 1.5) {
                Text("Delete your overall budget?")
                    .font(.system(.title2, design: .rounded).weight(.medium))
                    .foregroundStyle(Color.PrimaryText)

                Text("This action cannot be undone.")
                    .font(.system(.title3, design: .rounded).weight(.medium))
                    .foregroundStyle(Color.SubtitleText)
                    .padding(.bottom, 25)

                Button {
                    dismiss()

                    withAnimation {
                        budgetVM.deleteMain(toDelete)
                    }

                } label: {
                    DeleteButton(text: String.appLocalized("Delete"), red: true)
                }
                .padding(.bottom, 8)

                Button {
                    withAnimation(.easeOut(duration: 0.7)) {
                        dismiss()
                    }

                } label: {
                    DeleteButton(text: String.appLocalized("Cancel"), red: false)
                }
            }
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(13)
            .glassCard(in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 13).stroke(systemColorScheme == .dark ? Color.gray.opacity(0.1) : Color.clear, lineWidth: 1.3))
            .offset(y: offset)
            .gesture(
                DragGesture()
                    .onChanged { gesture in
                        if gesture.translation.height < 0 {
                            offset = gesture.translation.height / 3
                        } else {
                            offset = gesture.translation.height
                        }
                    }
                    .onEnded { value in
                        if value.translation.height > 20 {
                            dismiss()
                        } else {
                            withAnimation {
                                offset = 0
                            }
                        }
                    }
            )
            .padding(.horizontal, 17)
            .padding(.bottom, bottomEdge == 0 ? 13 : bottomEdge)
        }
        .ignoresSafeArea(.all)
        .background(BackgroundBlurView())
    }
}

struct DetailedBudgetView: View {
    @Environment(\.dismiss) var dismiss
    let budget: BudgetModel

    @State private var toDelete: BudgetModel?

    @State var newTransaction = false

    @State private var toEdit: BudgetModel?

    var body: some View {
        VStack(spacing: 15) {
            HStack {
                Button {
                    dismiss()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                            .foregroundStyle(Color.SubtitleText)

                        Text(String.appLocalized("Back"))
                            .font(.system(.body, design: .rounded).weight(.semibold))
                            .foregroundStyle(Color.SubtitleText)
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 8)
                    .fixedSize(horizontal: false, vertical: /*@START_MENU_TOKEN@*/true/*@END_MENU_TOKEN@*/)
                    .background(Color.SecondaryBackground, in: Capsule())
                }

                Spacer()

                DetailedBudgetViewTopBarButton(imageName: "plus", color: Color("110"), label: String.appLocalized("Add transaction")) {
                    newTransaction = true
                }

                DetailedBudgetViewTopBarButton(imageName: "pencil", color: Color("6"), label: String.appLocalized("Edit budget")) {
                    toEdit = budget
                }

                DetailedBudgetViewTopBarButton(imageName: "trash.fill", color: Color.AlertRed, label: String.appLocalized("Delete budget")) {
                    toDelete = budget
                }
            }
            .padding(.horizontal, 20)

            TimeBudgetView(budget: budget)
        }
        .padding(.vertical, 15)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .appBackground()
        .sheet(item: $toEdit, onDismiss: {
            toEdit = nil
        }) { budget in
            BrandNewBudgetView(overallBudgetCreated: false, toEditBudget: budget)
        }
        .fullScreenCover(isPresented: $newTransaction) {
            TransactionView(category: budget.category)
        }
        .fullScreenCover(item: $toDelete, onDismiss: {
            toDelete = nil
        }) { budget in
            DeleteBudgetAlert(toDelete: budget)
        }
    }
}

struct DetailedMainBudgetView: View {
    @Environment(\.dismiss) var dismiss
    let budget: MainBudgetModel

    @State private var toDelete: MainBudgetModel?

    @State private var toEdit: MainBudgetModel?

    var body: some View {
        VStack(spacing: 15) {
            HStack {
                Button {
                    dismiss()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                            .foregroundStyle(Color.SubtitleText)

                        Text(String.appLocalized("Back"))
                            .font(.system(.body, design: .rounded).weight(.semibold))
                            .foregroundStyle(Color.SubtitleText)
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 8)
                    .fixedSize(horizontal: false, vertical: /*@START_MENU_TOKEN@*/true/*@END_MENU_TOKEN@*/)
//                    .frame(height: 30, alignment: .center)
                    .background(Color.SecondaryBackground, in: Capsule())
                }

                Spacer()

                DetailedBudgetViewTopBarButton(imageName: "pencil", color: Color("6"), label: String.appLocalized("Edit budget")) {
                    toEdit = budget
                }

                DetailedBudgetViewTopBarButton(imageName: "trash.fill", color: Color.AlertRed, label: String.appLocalized("Delete budget")) {
                    toDelete = budget
                }
            }
            .padding(.horizontal, 20)

            TimeMainBudgetView(budget: budget)
        }
        .padding(.vertical, 15)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .appBackground()
        .fullScreenCover(item: $toEdit, onDismiss: {
            toEdit = nil
        }) { budget in
            BrandNewBudgetView(overallBudgetCreated: true, toEditMainBudget: budget)
        }
        .fullScreenCover(item: $toDelete, onDismiss: {
            toDelete = nil
        }) { budget in
            DeleteMainBudgetAlert(toDelete: budget)
        }
    }
}

struct TimeBudgetView: View {
    let budget: BudgetModel

    var budgetAmount: Double {
        return budget.amount
    }

    var budgetType: Int {
        return Int(budget.type)
    }

    @State var startDate = Date.now

    var dateString: String {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale.appLocale

        if budgetType == 1 {
            dateFormatter.dateFormat = "d MMM yyyy"
            return dateFormatter.string(from: startDate)
        } else if budgetType == 2 {
            let endDate = Calendar.current.date(byAdding: .day, value: 6, to: startDate) ?? Date.now
            dateFormatter.dateFormat = "d MMM"
            return dateFormatter.string(from: startDate) + " - " + dateFormatter.string(from: endDate)
        } else if budgetType == 3 {
            var endDate = Calendar.current.date(byAdding: .month, value: 1, to: startDate)!
            endDate = Calendar.current.date(byAdding: .day, value: -1, to: endDate)!
            dateFormatter.dateFormat = "d MMM"
            return dateFormatter.string(from: startDate) + " - " + dateFormatter.string(from: endDate)
        } else if budgetType == 4 {
            var endDate = Calendar.current.date(byAdding: .year, value: 1, to: startDate)!
            endDate = Calendar.current.date(byAdding: .day, value: -1, to: endDate)!
            dateFormatter.dateFormat = "d MMM yy"
            return dateFormatter.string(from: startDate) + " - " + dateFormatter.string(from: endDate)
        } else {
            return ""
        }
    }

    @State var totalSpent = 0.0

    var timeLeft: String {
        let calendar = Calendar.current

        if budgetType == 1 {
            let components = calendar.dateComponents([.hour], from: budget.wrappedDate, to: Date.now)
            return String(format: String.appLocalized("%@ hours left"), "\(24 - (components.hour ?? 0))")
        } else {
            return String(format: String.appLocalized("%@ days left"), "\(daysLeftNumber)")
        }
    }

    var subtitleText: String {
        if budget.startDate == startDate {
            return timeLeft
        } else {
            return dateString
        }
    }

    @AppStorage("currency", store: .appGroup) var currency: String = Locale.current.currency?.identifier ?? "USD"
    var currencySymbol: String {
        return Locale.appCurrencySymbol(forCurrencyCode: currency)
    }

    var difference: Double {
        abs(budgetAmount - totalSpent)
    }

    var differenceSubtitle: String {
        if budgetAmount >= totalSpent {
            if startDate == budget.startDate {
                if budgetType == 1 {
                    return String.appLocalized("left today")
                } else if budgetType == 2 {
                    return String.appLocalized("left this week")
                } else if budgetType == 3 {
                    return String.appLocalized("left this month")
                } else if budgetType == 4 {
                    return String.appLocalized("left this year")
                } else {
                    return ""
                }
            } else {
                if budgetType == 1 {
                    let dateFormatter = DateFormatter()
                    dateFormatter.locale = Locale.appLocale
                    dateFormatter.dateFormat = "d MMM"
                    return String(format: String.appLocalized("left on %@"), dateFormatter.string(from: startDate))
                } else if budgetType == 2 {
                    let components = Calendar.current.dateComponents([.day], from: startDate, to: budget.wrappedDate)
                    let weekString = String(format: String.appLocalized("%@ weeks ago"), "\((components.day ?? 0) / 7)")
                    return String(format: String.appLocalized("left %@"), weekString)
                } else if budgetType == 3 {
                    let components = Calendar.current.dateComponents([.month], from: startDate, to: budget.wrappedDate)
                    let monthString = String(format: String.appLocalized("%@ months ago"), "\(components.month!)")
                    return String(format: String.appLocalized("left %@"), monthString)
                } else if budgetType == 4 {
                    let components = Calendar.current.dateComponents([.year], from: startDate, to: budget.wrappedDate)
                    let yearString = String(format: String.appLocalized("%@ years ago"), "\(components.year!)")
                    return String(format: String.appLocalized("left %@"), yearString)
                } else {
                    return ""
                }
            }
        } else {
            if startDate == budget.startDate {
                if budgetType == 1 {
                    return String.appLocalized("over today")
                } else if budgetType == 2 {
                    return String.appLocalized("over this week")
                } else if budgetType == 3 {
                    return String.appLocalized("over this month")
                } else if budgetType == 4 {
                    return String.appLocalized("over this year")
                } else {
                    return ""
                }
            } else {
                if budgetType == 1 {
                    let dateFormatter = DateFormatter()
                    dateFormatter.locale = Locale.appLocale
                    dateFormatter.dateFormat = "d MMM"
                    return String(format: String.appLocalized("over on %@"), dateFormatter.string(from: startDate))
                } else if budgetType == 2 {
                    let components = Calendar.current.dateComponents([.day], from: startDate, to: budget.wrappedDate)
                    let weekString = String(format: String.appLocalized("%@ weeks ago"), "\((components.day ?? 0) / 7)")
                    return String(format: String.appLocalized("over %@"), weekString)
                } else if budgetType == 3 {
                    let components = Calendar.current.dateComponents([.month], from: startDate, to: budget.wrappedDate)
                    let monthString = String(format: String.appLocalized("%@ months ago"), "\(components.month!)")
                    return String(format: String.appLocalized("over %@"), monthString)
                } else if budgetType == 4 {
                    let components = Calendar.current.dateComponents([.year], from: startDate, to: budget.wrappedDate)
                    let yearString = String(format: String.appLocalized("%@ years ago"), "\(components.year!)")
                    return String(format: String.appLocalized("over %@"), yearString)
                } else {
                    return ""
                }
            }
        }
    }

    // for week, month, year only

    var daysLeftNumber: Int {
        let calendar = Calendar.current

        if budgetType == 1 {
            return 0
        } else if budgetType == 2 {
            let components = calendar.dateComponents([.day], from: budget.wrappedDate, to: Date.now)
            return 7 - (components.day ?? 0)
        } else if budgetType == 3 {
            let components1 = calendar.dateComponents([.day], from: budget.wrappedDate, to: budget.endDate)
            let numberOfDays = components1.day!
            let components2 = calendar.dateComponents([.day], from: budget.wrappedDate, to: Date.now)
            let numberOfDaysPast = components2.day!

            return Int(numberOfDays - numberOfDaysPast)
        } else if budgetType == 4 {
            let components1 = calendar.dateComponents([.day], from: budget.wrappedDate, to: budget.endDate)
            let numberOfDays = components1.day!
            let components2 = calendar.dateComponents([.day], from: budget.wrappedDate, to: Date.now)
            let numberOfDaysPast = components2.day!
            return Int(numberOfDays - numberOfDaysPast)
        } else {
            return 0
        }
    }

    var leftPerDay: Double {
        if budgetType >= 2 {
            return (budgetAmount - totalSpent) / Double(daysLeftNumber)
        } else {
            return 0
        }
    }

    var showExtraDetails: Bool {
        if budgetType >= 2 {
            return budget.startDate == startDate && totalSpent < budgetAmount && daysLeftNumber != 1
        } else {
            return false
        }
    }

    var body: some View {
        VStack(spacing: 20) {
            // budget name and emoji and time left
            VStack(spacing: 10) {
                HStack(spacing: 7.5) {
                    Text(budget.wrappedEmoji)
                        .font(.system(.subheadline, design: .rounded))
                    Text(budget.wrappedName)
                        .font(.system(.title3, design: .rounded).weight(.medium))
                        .lineLimit(1)
                }
                .foregroundStyle(Color.PrimaryText)

                Text(subtitleText)
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundStyle(Color.SubtitleText)
                    .padding(4)
                    .padding(.horizontal, 7)
                    .background(Color.SecondaryBackground, in: Capsule())
            }
            .padding(.bottom, 15)

            // amount left and averages

            if budgetType >= 2 {
                HStack(alignment: .top, spacing: 15) {
                    VStack(alignment: showExtraDetails ? .leading : .center, spacing: -4) {
                        DetailedBudgetDifferenceDollarView(amount: difference, red: totalSpent >= budgetAmount)

                        Text(differenceSubtitle)
                            .font(.system(.subheadline, design: .rounded).weight(.medium))
                            .foregroundStyle(Color.SubtitleText)
                    }
                    .frame(maxWidth: .infinity, alignment: showExtraDetails ? .leading : .center)

                    if showExtraDetails {
                        VStack(alignment: .trailing, spacing: -4) {
                            DetailedBudgetDollarView(amount: leftPerDay)

                            Text("left each day")
                                .font(.system(.subheadline, design: .rounded).weight(.medium))
//                                .font(.system(size: 15, weight: .medium, design: .rounded))
                                .foregroundStyle(Color.SubtitleText)
                        }
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 25)
            } else {
                VStack(spacing: -4) {
                    DetailedBudgetDifferenceDollarView(amount: difference, red: totalSpent >= budgetAmount)

                    Text(differenceSubtitle)
                        .font(.system(.subheadline, design: .rounded).weight(.medium))
//                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.SubtitleText)
                }
                .padding(.horizontal, 25)
            }

            // bar graph

            VStack(spacing: 5) {
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 11.5, style: .continuous)
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
                }
                .frame(height: 28)

                HStack {
                    Text("\(currencySymbol)\(totalSpent.formatted(.number.precision(.fractionLength(2))))")
                    Spacer()
                    Text("\(currencySymbol)\(budgetAmount.formatted(.number.precision(.fractionLength(2))))")
                }
                .frame(maxWidth: .infinity)
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(Color.SubtitleText)
            }
            .padding(.bottom, budgetType >= 2 ? 20 : 0)
            .padding(.horizontal, 25)

            if budgetType == 1 {
                Divider()
                    .overlay(Color.Outline)
                    .padding(.horizontal, 25)
            }

            if let category = budget.category {
                ScrollView(showsIndicators: false) {
                    if budgetType == 1 {
                        FilteredCategoryDayBudgetView(category: category, day: startDate, totalSpent: $totalSpent)
                            .padding(.horizontal, 15)
                    } else {
                        FilteredBudgetView(category: category, startDate: startDate, totalSpent: $totalSpent, type: budgetType - 1)
                            .padding(.horizontal, 15)
                    }
                }
                .frame(maxHeight: .infinity)

                BudgetStepperView(category: category, date: $startDate, startDate: budget.wrappedDate, budgetType: budgetType)
                    .padding(.horizontal, 25)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onAppear {
            startDate = budget.wrappedDate
        }
    }
}

struct FilteredCategoryDayBudgetView: View {
    @Query private var transactions: [TransactionModel]
    @Binding var totalSpent: Double
    @AppStorage("currency", store: .appGroup) var currency: String = Locale.current.currency?.identifier ?? "USD"
    var currencySymbol: String {
        return Locale.appCurrencySymbol(forCurrencyCode: currency)
    }

    var date: Date

    @AppStorage("showCents", store: .appGroup) var showCents: Bool = true
    @AppStorage("swapTimeLabel", store: .appGroup) var swapTimeLabel: Bool = false
    @AppStorage("showExpenseOrIncomeSign", store: .appGroup)
    var showExpenseOrIncomeSign: Bool = true

    var body: some View {
        VStack(spacing: 0) {
            if transactions.count == 0 {
                NoResultsView(fullscreen: false)
            } else {
                ForEach(transactions, id: \.id) { transaction in
                    SingleTransactionView(transaction: transaction, showCents: showCents, currencySymbol: currencySymbol, currency: currency, swapTimeLabel: swapTimeLabel, future: false, showExpenseOrIncomeSign: showExpenseOrIncomeSign)
                }
            }
        }
        .onAppear {
            DispatchQueue.main.async {
                var holding = 0.0
                transactions.forEach { transaction in

                    holding += transaction.wrappedAmount
                }

                totalSpent = holding
            }
        }
        .onChange(of: date) { _, _ in
            DispatchQueue.main.async {
                var holding = 0.0
                transactions.forEach { transaction in

                    holding += transaction.wrappedAmount
                }

                totalSpent = holding
            }
        }
//        .fullScreenCover(item: $toDelete, onDismiss: {
//            toDelete = nil
//        }) { transaction in
//            DeleteTransactionAlert(toDelete: transaction, stopRecurring: false)
//        }
//        .fullScreenCover(item: $toEdit, onDismiss: {
//            toEdit = nil
//        }) { transaction in
//            TransactionView(toEdit: transaction)
//        }
        .frame(maxHeight: .infinity)
    }

    init(category: CategoryModel?, day: Date, totalSpent: Binding<Double>) {
        date = day
        let now = Date.now
        let past = Date.distantPast
        let future = Date.distantFuture

        if let unwrappedCategory = category {
            let categoryId = unwrappedCategory.id
            _transactions = Query(filter: #Predicate<TransactionModel> {
                ($0.day ?? past) == day && !$0.income && ($0.date ?? future) <= now && $0.category?.id == categoryId
            }, sort: [SortDescriptor(\.date, order: .reverse)])
        } else {
            _transactions = Query(filter: #Predicate<TransactionModel> {
                ($0.day ?? past) == day && !$0.income && ($0.date ?? future) <= now
            }, sort: [SortDescriptor(\.date, order: .reverse)])
        }

        _totalSpent = totalSpent
    }
}

struct FilteredBudgetView: View {
    @Query private var transactions: [TransactionModel]

    @Binding var totalSpent: Double
    var date: Date

    @AppStorage("showCents", store: .appGroup) var showCents: Bool = true
    @AppStorage("currency", store: .appGroup) var currency: String = Locale.current.currency?.identifier ?? "USD"
    var currencySymbol: String {
        return Locale.appCurrencySymbol(forCurrencyCode: currency)
    }

    @AppStorage("showExpenseOrIncomeSign", store: .appGroup)
    var showExpenseOrIncomeSign: Bool = true

    @AppStorage("swapTimeLabel", store: .appGroup) var swapTimeLabel: Bool = false

    private var groupedByDay: [(day: Date, transactions: [TransactionModel])] {
        let grouped = Dictionary(grouping: transactions) { $0.day ?? Date.now }
        return grouped.keys.sorted(by: >).map { day in
            (day: day, transactions: grouped[day]!.sorted { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) })
        }
    }

    private func dayTotal(_ dayTransactions: [TransactionModel]) -> Double {
        dayTransactions.reduce(0.0) { $0 + ($1.income ? $1.amount : -$1.amount) }
    }

    private func dayTotalString(_ total: Double) -> String {
        let numberFormatter = NumberFormatter()
        numberFormatter.locale = Locale.appLocale
        numberFormatter.numberStyle = .currency
        numberFormatter.currencyCode = currency
        numberFormatter.maximumFractionDigits = showCents ? 2 : 0

        if total >= 0 {
            return "+" + (numberFormatter.string(from: NSNumber(value: total)) ?? "$0")
        } else {
            return numberFormatter.string(from: NSNumber(value: total)) ?? "$0"
        }
    }

    var body: some View {
        VStack(spacing: 30) {
            if transactions.count == 0 {
                NoResultsView(fullscreen: false)
            }

            LazyVStack(spacing: 0) {
                ForEach(groupedByDay, id: \.day) { entry in
                    let total = dayTotal(entry.transactions)
                    let dateText = dateConverter(date: entry.day).uppercased()
                    let totalString = abs(total).formatted(.number.precision(.fractionLength(2)))

                    VStack(spacing: 0) {
                        VStack(spacing: 4) {
                            HStack {
                                Text(dateText)
                                Spacer()

                                Text(dayTotalString(total))
                                    .layoutPriority(1)
                            }
                            .font(.system(.callout, design: .rounded).weight(.semibold))
                            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                            .foregroundStyle(Color.SubtitleText)
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel(String(format: String.appLocalized("%@%@ was spent %@"), currencySymbol, totalString, dateConverterAccessibilityLabel(date: entry.day)))

                            Line()
                                .stroke(Color.Outline, style: StrokeStyle(lineWidth: 1.3, lineCap: .round))
                        }
                        .padding(.horizontal, 10)
                        .padding(.top, 10)

                        ForEach(entry.transactions, id: \.id) { transaction in
                            SingleTransactionView(transaction: transaction, showCents: showCents, currencySymbol: currencySymbol, currency: currency, swapTimeLabel: swapTimeLabel, future: false, showExpenseOrIncomeSign: showExpenseOrIncomeSign)
                        }
                    }
                    .padding(.bottom, 18)
                }
            }
        }
        .frame(maxHeight: .infinity)
        .onAppear {
            totalSpent = transactions.reduce(0.0) { $0 + $1.amount }
        }
        .onChange(of: date) { _, _ in
            totalSpent = transactions.reduce(0.0) { $0 + $1.amount }
        }
    }

    init(category: CategoryModel? = nil, startDate: Date, totalSpent: Binding<Double>, type: Int) {
        date = startDate

        var calendar = Calendar(identifier: .gregorian)

        calendar.firstWeekday = UserDefaults.appGroup.integer(forKey: "firstWeekday")
        calendar.minimumDaysInFirstWeek = 4

        let endDate: Date

        if type == 1 {
            if calendar.isDate(startDate, equalTo: Date.now, toGranularity: .weekOfYear) {
                endDate = Date.now
            } else {
                endDate = calendar.date(byAdding: .day, value: 7, to: startDate) ?? Date.now
            }
        } else if type == 2 {
            if calendar.isDate(startDate, equalTo: Date.now, toGranularity: .month) {
                endDate = Date.now
            } else {
                endDate = calendar.date(byAdding: .month, value: 1, to: startDate) ?? Date.now
            }
        } else {
            if calendar.isDate(startDate, equalTo: Date.now, toGranularity: .year) {
                endDate = Date.now
            } else {
                endDate = calendar.date(byAdding: .year, value: 1, to: startDate) ?? Date.now
            }
        }

        let past = Date.distantPast
        let future = Date.distantFuture

        if let unwrappedCategory = category {
            let categoryId = unwrappedCategory.id
            _transactions = Query(filter: #Predicate<TransactionModel> {
                !$0.income && ($0.date ?? past) >= startDate && ($0.date ?? future) < endDate && $0.category?.id == categoryId
            })
        } else {
            _transactions = Query(filter: #Predicate<TransactionModel> {
                !$0.income && ($0.date ?? past) >= startDate && ($0.date ?? future) < endDate
            })
        }

        _totalSpent = totalSpent
    }
}

struct TimeMainBudgetView: View {
    let budget: MainBudgetModel

    var budgetAmount: Double {
        return budget.amount
    }

    var budgetType: Int {
        return Int(budget.type)
    }

    @State var startDate = Date.now

    var dateString: String {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale.appLocale

        if budgetType == 1 {
            dateFormatter.dateFormat = "d MMM yyyy"
            return dateFormatter.string(from: startDate)
        } else if budgetType == 2 {
            let endDate = Calendar.current.date(byAdding: .day, value: 6, to: startDate) ?? Date.now
            dateFormatter.dateFormat = "d MMM"
            return dateFormatter.string(from: startDate) + " - " + dateFormatter.string(from: endDate)
        } else if budgetType == 3 {
            var endDate = Calendar.current.date(byAdding: .month, value: 1, to: startDate)!
            endDate = Calendar.current.date(byAdding: .day, value: -1, to: endDate)!
            dateFormatter.dateFormat = "d MMM"
            return dateFormatter.string(from: startDate) + " - " + dateFormatter.string(from: endDate)
        } else if budgetType == 4 {
            var endDate = Calendar.current.date(byAdding: .year, value: 1, to: startDate)!
            endDate = Calendar.current.date(byAdding: .day, value: -1, to: endDate)!
            dateFormatter.dateFormat = "d MMM yy"
            return dateFormatter.string(from: startDate) + " - " + dateFormatter.string(from: endDate)
        } else {
            return ""
        }
    }

    @State var totalSpent = 0.0

    var timeLeft: String {
        let calendar = Calendar.current

        if budgetType == 1 {
            let components = calendar.dateComponents([.hour], from: budget.wrappedDate, to: Date.now)
            return String(format: String.appLocalized("%@ hours left"), "\(24 - (components.hour ?? 0))")
        } else {
            return String(format: String.appLocalized("%@ days left"), "\(daysLeftNumber)")
        }
    }

    var subtitleText: String {
        if budget.startDate == startDate {
            return timeLeft
        } else {
            return dateString
        }
    }

    @AppStorage("currency", store: .appGroup) var currency: String = Locale.current.currency?.identifier ?? "USD"
    var currencySymbol: String {
        return Locale.appCurrencySymbol(forCurrencyCode: currency)
    }

    var difference: Double {
        abs(budgetAmount - totalSpent)
    }

    var differenceSubtitle: String {
        if budgetAmount >= totalSpent {
            if startDate == budget.startDate {
                if budgetType == 1 {
                    return String.appLocalized("left today")
                } else if budgetType == 2 {
                    return String.appLocalized("left this week")
                } else if budgetType == 3 {
                    return String.appLocalized("left this month")
                } else if budgetType == 4 {
                    return String.appLocalized("left this year")
                } else {
                    return ""
                }
            } else {
                if budgetType == 1 {
                    let dateFormatter = DateFormatter()
                    dateFormatter.locale = Locale.appLocale
                    dateFormatter.dateFormat = "d MMM"
                    return String(format: String.appLocalized("left on %@"), dateFormatter.string(from: startDate))
                } else if budgetType == 2 {
                    let components = Calendar.current.dateComponents([.day], from: startDate, to: budget.wrappedDate)
                    let weekString = String(format: String.appLocalized("%@ weeks ago"), "\((components.day ?? 0) / 7)")
                    return String(format: String.appLocalized("left %@"), weekString)
                } else if budgetType == 3 {
                    let components = Calendar.current.dateComponents([.month], from: startDate, to: budget.wrappedDate)
                    let monthString = String(format: String.appLocalized("%@ months ago"), "\(components.month!)")
                    return String(format: String.appLocalized("left %@"), monthString)
                } else if budgetType == 4 {
                    let components = Calendar.current.dateComponents([.year], from: startDate, to: budget.wrappedDate)
                    let yearString = String(format: String.appLocalized("%@ years ago"), "\(components.year!)")
                    return String(format: String.appLocalized("left %@"), yearString)
                } else {
                    return ""
                }
            }
        } else {
            if startDate == budget.startDate {
                if budgetType == 1 {
                    return String.appLocalized("over today")
                } else if budgetType == 2 {
                    return String.appLocalized("over this week")
                } else if budgetType == 3 {
                    return String.appLocalized("over this month")
                } else if budgetType == 4 {
                    return String.appLocalized("over this year")
                } else {
                    return ""
                }
            } else {
                if budgetType == 1 {
                    let dateFormatter = DateFormatter()
                    dateFormatter.locale = Locale.appLocale
                    dateFormatter.dateFormat = "d MMM"
                    return String(format: String.appLocalized("over on %@"), dateFormatter.string(from: startDate))
                } else if budgetType == 2 {
                    let components = Calendar.current.dateComponents([.day], from: startDate, to: budget.wrappedDate)
                    let weekString = String(format: String.appLocalized("%@ weeks ago"), "\((components.day ?? 0) / 7)")
                    return String(format: String.appLocalized("over %@"), weekString)
                } else if budgetType == 3 {
                    let components = Calendar.current.dateComponents([.month], from: startDate, to: budget.wrappedDate)
                    let monthString = String(format: String.appLocalized("%@ months ago"), "\(components.month!)")
                    return String(format: String.appLocalized("over %@"), monthString)
                } else if budgetType == 4 {
                    let components = Calendar.current.dateComponents([.year], from: startDate, to: budget.wrappedDate)
                    let yearString = String(format: String.appLocalized("%@ years ago"), "\(components.year!)")
                    return String(format: String.appLocalized("over %@"), yearString)
                } else {
                    return ""
                }
            }
        }
    }

    // for week, month, year only

    var daysLeftNumber: Int {
        let calendar = Calendar.current

        if budgetType == 1 {
            return 0
        } else if budgetType == 2 {
            let components = calendar.dateComponents([.day], from: budget.wrappedDate, to: Date.now)
            return 7 - (components.day ?? 0)
        } else if budgetType == 3 {
            let components1 = calendar.dateComponents([.day], from: budget.wrappedDate, to: budget.endDate)
            let numberOfDays = components1.day!
            let components2 = calendar.dateComponents([.day], from: budget.wrappedDate, to: Date.now)
            let numberOfDaysPast = components2.day!

            return Int(numberOfDays - numberOfDaysPast)
        } else if budgetType == 4 {
            let components1 = calendar.dateComponents([.day], from: budget.wrappedDate, to: budget.endDate)
            let numberOfDays = components1.day!
            let components2 = calendar.dateComponents([.day], from: budget.wrappedDate, to: Date.now)
            let numberOfDaysPast = components2.day!
            return Int(numberOfDays - numberOfDaysPast)
        } else {
            return 0
        }
    }

    var leftPerDay: Double {
        if budgetType >= 2 {
            return (budgetAmount - totalSpent) / Double(daysLeftNumber)
        } else {
            return 0
        }
    }

    var showExtraDetails: Bool {
        if budgetType >= 2 {
            return budget.startDate == startDate && totalSpent < budgetAmount && daysLeftNumber != 1
        } else {
            return false
        }
    }

    var body: some View {
        VStack(spacing: 20) {
            // budget name and emoji and time left
            VStack(spacing: 10) {
                Text("Overall Budget")
                    .font(.system(.title3, design: .rounded).weight(.medium))
                    .lineLimit(1)
                    .foregroundStyle(Color.PrimaryText)

                Text(subtitleText)
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundStyle(Color.SubtitleText)
                    .padding(4)
                    .padding(.horizontal, 7)
                    .background(Color.SecondaryBackground, in: Capsule())
            }
            .padding(.bottom, 15)

            // amount left and averages

            if budgetType >= 2 {
                HStack(alignment: .top, spacing: 15) {
                    VStack(alignment: showExtraDetails ? .leading : .center, spacing: -4) {
                        DetailedBudgetDifferenceDollarView(amount: difference, red: totalSpent >= budgetAmount)

                        Text(differenceSubtitle)
                            .font(.system(.subheadline, design: .rounded).weight(.medium))
                            .foregroundStyle(Color.SubtitleText)
                    }
                    .frame(maxWidth: .infinity, alignment: showExtraDetails ? .leading : .center)

                    if showExtraDetails {
                        VStack(alignment: .trailing, spacing: -4) {
                            DetailedBudgetDollarView(amount: leftPerDay)

                            Text("left each day")
                                .font(.system(.subheadline, design: .rounded).weight(.medium))
                                .foregroundStyle(Color.SubtitleText)
                        }
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 25)
            } else {
                VStack(spacing: -4) {
                    DetailedBudgetDifferenceDollarView(amount: difference, red: totalSpent >= budgetAmount)

                    Text(differenceSubtitle)
                        .font(.system(.subheadline, design: .rounded).weight(.medium))
                        .foregroundStyle(Color.SubtitleText)
                }
                .padding(.horizontal, 25)
            }

            // bar graph

            VStack(spacing: 5) {
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 11.5, style: .continuous)
                            .fill(Color.SecondaryBackground)
                            .frame(width: proxy.size.width)

                        if totalSpent / budgetAmount < 0.98 {
                            AnimatedHorizontalBarGraphMainBudget()
                                .frame(width: proxy.size.width * (1 - totalSpent / budgetAmount))
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .frame(height: 28)

                HStack {
                    Text("\(currencySymbol)\(totalSpent.formatted(.number.precision(.fractionLength(2))))")
                    Spacer()
                    Text("\(currencySymbol)\(budgetAmount.formatted(.number.precision(.fractionLength(2))))")
                }
                .frame(maxWidth: .infinity)
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(Color.SubtitleText)
            }
            .padding(.bottom, budgetType >= 2 ? 20 : 0)
            .padding(.horizontal, 25)

            if budgetType == 1 {
                Divider()
                    .overlay(Color.Outline)
                    .padding(.horizontal, 25)
            }

            ScrollView(showsIndicators: false) {
                if budgetType == 1 {
                    FilteredCategoryDayBudgetView(category: nil, day: startDate, totalSpent: $totalSpent)
                        .padding(.horizontal, 15)
                } else {
                    FilteredBudgetView(category: nil, startDate: startDate, totalSpent: $totalSpent, type: budgetType - 1)
                        .padding(.horizontal, 15)
                }
            }
            .frame(maxHeight: .infinity)

            BudgetStepperView(category: nil, date: $startDate, startDate: budget.wrappedDate, budgetType: budgetType)
                .padding(.horizontal, 25)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onAppear {
            startDate = budget.wrappedDate
        }
    }
}

struct AnimatedHorizontalBarGraphBudget: View {
    let category: CategoryModel

    @State var showBar: Bool = false
    @AppStorage("animated", store: .appGroup) var animated: Bool = true

    var body: some View {
        HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 11.5, style: .continuous)
                .foregroundStyle(Color(hex: category.wrappedColour))
                .frame(width: showBar ? nil : 0, alignment: .leading)

            Spacer(minLength: 0)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now()) {
                if !animated {
                    showBar = true
                } else {
                    withAnimation(.easeInOut(duration: 0.7)) {
                        showBar = true
                    }
                }
            }
        }
    }
}

struct AnimatedHorizontalBarGraphMainBudget: View {
    @State var showBar: Bool = false
    @AppStorage("animated", store: .appGroup) var animated: Bool = true

    var body: some View {
        HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 11.5, style: .continuous)
                .fill(Color.DarkBackground)
                .frame(width: showBar ? nil : 0, alignment: .leading)

            Spacer(minLength: 0)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now()) {
                if !animated {
                    showBar = true
                } else {
                    withAnimation(.easeInOut(duration: 0.7)) {
                        showBar = true
                    }
                }
            }
        }
    }
}

struct AnimatedCurvedBarGraphBudget: View {
    var totalSpent: Double
    var budgetTotal: Double
    let cornerRadius: Double
    let width: Double
    let color: String
    @State var percent: Double = 0

    @AppStorage("animated", store: .appGroup) var animated: Bool = true

    var body: some View {
        DonutSemicircle(percent: percent, cornerRadius: cornerRadius, width: width)
            .fill(Color(color))
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now()) {
                    if !animated {
                        percent = 1 - (totalSpent / budgetTotal)
                    } else {
                        withAnimation(.easeInOut(duration: 0.7)) {
                            percent = 1 - (totalSpent / budgetTotal)
                        }
                    }
                }
            }
    }
}

struct AnimatedCurvedBarGraphMainBudget: View {
    var totalSpent: Double
    var budgetTotal: Double
    let cornerRadius: Double
    let width: Double

    @State var percent: Double = 0

    @AppStorage("animated", store: .appGroup) var animated: Bool = true

    var body: some View {
        DonutSemicircle(percent: percent, cornerRadius: cornerRadius, width: width)
            .fill(Color.DarkBackground)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now()) {
                    if !animated {
                        percent = 1 - (totalSpent / budgetTotal)
                    } else {
                        withAnimation(.easeInOut(duration: 0.7)) {
                            percent = 1 - (totalSpent / budgetTotal)
                        }
                    }
                }
            }
    }
}

struct BudgetStepperView: View {
    @Query private var transactions: [TransactionModel]

    @Binding var date: Date
    var firstDate: Date {
        if transactions.isEmpty {
            return Date.now
        } else {
            return transactions[0].day ?? Date.now
        }
    }

    var endDate: Date {
        if type == 1 {
            return Calendar.current.date(byAdding: .day, value: 1, to: date)!
        } else if type == 2 {
            return Calendar.current.date(byAdding: .day, value: 6, to: date)!
        } else if type == 3 {
            let holdingDate = Calendar.current.date(byAdding: .month, value: 1, to: date)!
            return Calendar.current.date(byAdding: .day, value: -1, to: holdingDate)!
        } else if type == 4 {
            let holdingDate = Calendar.current.date(byAdding: .year, value: 1, to: date)!
            return Calendar.current.date(byAdding: .day, value: -1, to: holdingDate)!
        }

        return startDate
    }

    let startDate: Date
    let type: Int

    var dateString: String {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale.appLocale

        if type == 1 {
            dateFormatter.dateFormat = "d MMM yyyy"
            return dateFormatter.string(from: date)
        } else if type == 4 {
            dateFormatter.dateFormat = "d MMM yy"
            return dateFormatter.string(from: date) + " - " + dateFormatter.string(from: endDate)
        } else {
            dateFormatter.dateFormat = "d MMM"
            return dateFormatter.string(from: date) + " - " + dateFormatter.string(from: endDate)
        }
    }

    var body: some View {
        HStack {
            StepperButtonView(left: true, disabled: date <= firstDate) {
                if date > firstDate {
                    if type == 1 {
                        date = Calendar.current.date(byAdding: .day, value: -1, to: date)!
                    } else if type == 2 {
                        date = Calendar.current.date(byAdding: .day, value: -7, to: date)!
                    } else if type == 3 {
                        date = Calendar.current.date(byAdding: .month, value: -1, to: date)!
                    } else if type == 4 {
                        date = Calendar.current.date(byAdding: .year, value: -1, to: date)!
                    }
                }
            }

            Spacer()

            Text(dateString)
                .font(.system(.title3, design: .rounded).weight(.bold))

            Spacer()

            StepperButtonView(left: false, disabled: date == startDate) {
                if date < startDate {
                    if type == 1 {
                        date = Calendar.current.date(byAdding: .day, value: 1, to: date)!
                    } else if type == 2 {
                        date = Calendar.current.date(byAdding: .day, value: 7, to: date)!
                    } else if type == 3 {
                        date = Calendar.current.date(byAdding: .month, value: 1, to: date)!
                    } else if type == 4 {
                        date = Calendar.current.date(byAdding: .year, value: -1, to: date)!
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    init(category: CategoryModel?, date: Binding<Date>, startDate: Date, budgetType: Int) {
        if let unwrappedCategory = category {
            let categoryId = unwrappedCategory.id
            _transactions = Query(filter: #Predicate<TransactionModel> {
                $0.category?.id == categoryId
            }, sort: [SortDescriptor(\.day)])
        } else {
            _transactions = Query(sort: [SortDescriptor(\.day)])
        }

        _date = date

        self.startDate = startDate
        type = budgetType
    }
}

// MARK: - Arced Text (replaces CrookedText)
struct ArcedText: View {
    let text: String
    let radius: CGFloat

    @Environment(\.font) private var font

    var body: some View {
        Canvas { context, size in
            let resolvedFont = font ?? .footnote
            let resolvedColor: Color = .primary
            let midX = size.width / 2
            let midY = size.height
            let center = CGPoint(x: midX, y: midY)
            let charCount = text.count
            let totalAngle: CGFloat = .pi / 2.5
            let startAngle: CGFloat = .pi + totalAngle / 2
            let spacing: CGFloat = charCount > 1 ? totalAngle / CGFloat(charCount - 1) : 0

            for (index, character) in text.enumerated() {
                let angle = startAngle + CGFloat(index) * spacing
                let x = center.x + radius * cos(angle)
                let y = center.y + radius * sin(angle)
                let charText = Text(String(character)).font(resolvedFont).foregroundStyle(resolvedColor)
                let resolved = context.resolve(charText)
                let charSize = resolved.measure(in: .zero)
                context.draw(resolved, at: CGPoint(x: x - charSize.width / 2, y: y - charSize.height / 2))
            }
        }
    }
}
