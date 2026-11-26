//
//  SavingsGoalView.swift
//  smartbud
//
//  Savings goals live on the Accounts screen. The list is read from the
//  current ledger; editing a goal never touches a transaction unless the
//  user explicitly makes a deposit through "Save again".
//

import SwiftData
import SwiftUI

struct SavingsGoalListView: View {
    @Environment(SavingsGoalViewModel.self) private var vm
    @AppStorage("notificationsEnabled", store: .appGroup) private var notificationsEnabled = true
    @AppStorage("currency", store: .appGroup) private var currency: String =
        Locale.current.currency?.identifier ?? "USD"
    @AppStorage("showCents", store: .appGroup) private var showCents = true

    @State private var editing: SavingsGoalModel?
    @State private var showEditor = false
    @State private var depositing: SavingsGoalModel?
    @State private var depositAmount = ""
    @State private var sourceID: UUID?

    var body: some View {
        List {
            if vm.goals.isEmpty {
                Section {
                    SBEmptyState(
                        systemImage: "target",
                        title: String.appLocalized("No savings goals yet"),
                        message: String.appLocalized(
                            "Set a target and watch your progress here."),
                        actionTitle: String.appLocalized("Add goal"),
                        action: { showEditor = true }
                    )
                    .listRowSeparator(.hidden)
                }
            } else {
                Section {
                    ForEach(vm.goals) { goal in
                        row(goal)
                    }
                } footer: {
                    Text(String.appLocalized(
                        "Goals do not change balances or spending. Save again records a transfer when a card is linked."))
                }
            }
        }
        .navigationTitle(String.appLocalized("Savings Goals"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    editing = nil
                    showEditor = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel(String.appLocalized("Add goal"))
            }
        }
        .onAppear { vm.load() }
        .sheet(isPresented: $showEditor) {
            SavingsGoalEditorView(goal: editing)
                .environment(vm)
        }
        .sheet(item: $depositing) { goal in
            depositSheet(goal)
        }
    }

    private func row(_ goal: SavingsGoalModel) -> some View {
        let progress = vm.progress(for: goal)
        return HStack(spacing: 14) {
            SavingsProgressRing(progress: progress)
                .frame(width: 46, height: 46)
            VStack(alignment: .leading, spacing: 4) {
                Text(goal.name)
                    .font(.headline)
                Text(progressText(progress))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 4)
            VStack(alignment: .trailing, spacing: 4) {
                Text(Money.format(progress.remaining, currencyCode: currency,
                                  showsCents: showCents, locale: .appLocale))
                    .font(.subheadline.weight(.semibold))
                Text(String.appLocalized("Remaining"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            editing = goal
            showEditor = true
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                vm.remove(goal)
            } label: {
                Label(String.appLocalized("Delete"), systemImage: "trash")
            }
            Button {
                depositAmount = ""
                sourceID = nil
                depositing = goal
            } label: {
                Label(String.appLocalized("Save again"), systemImage: "arrow.down.circle")
            }
            .tint(.accentColor)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(goal.name), \(progressText(progress))")
    }

    private func progressText(_ progress: SavingsProgress) -> String {
        switch progress.state {
        case .achieved:
            return String.appLocalized("Achieved")
        case .overdue:
            return String.appFormatted("Overdue · %@ to go today",
                                       Money.format(progress.dailyNeed, currencyCode: currency,
                                                    showsCents: showCents, locale: .appLocale))
        case .inProgress:
            return String.appFormatted(
                "%lld days left · %@ per day", progress.daysRemaining,
                Money.format(progress.dailyNeed, currencyCode: currency,
                             showsCents: showCents, locale: .appLocale))
        }
    }

    private func depositSheet(_ goal: SavingsGoalModel) -> some View {
        NavigationStack {
            Form {
                Section {
                    TextField("0", text: $depositAmount)
                        #if os(iOS)
                        .keyboardType(.decimalPad)
                        #endif
                } header: {
                    Text(String.appLocalized("Deposit amount"))
                }
                if !vm.accounts.isEmpty {
                    Section {
                        Picker(String.appLocalized("Source account"), selection: $sourceID) {
                            Text(String.appLocalized("None (manual tracking)"))
                                .tag(nil as UUID?)
                            ForEach(vm.accounts) { account in
                                Text(account.wrappedName).tag(account.id as UUID?)
                            }
                        }
                    } footer: {
                        Text(String.appLocalized(
                            "With a linked card, a deposit is recorded as a transfer; manual tracking only advances the goal."))
                    }
                }
                if let message = vm.message {
                    Section {
                        Text(message).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(String.appLocalized("Save again"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String.appLocalized("Cancel")) { depositing = nil }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String.appLocalized("Save")) {
                        let cleaned = depositAmount.replacingOccurrences(of: ",", with: ".")
                        guard let amount = Double(cleaned) else { return }
                        let source = sourceID.flatMap { id in
                            vm.accounts.first { $0.id == id }
                        }
                        Task {
                            if await vm.deposit(amount, into: goal, from: source,
                                                notificationsEnabled: notificationsEnabled),
                               vm.message == nil {
                                depositing = nil
                            }
                        }
                    }
                }
            }
        }
    }
}

/// Ring drawn from the progress fraction; a capped ratio keeps the stroke
/// closed for a goal that was over-funded.
struct SavingsProgressRing: View {
    let progress: SavingsProgress

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.2), lineWidth: 6)
            Circle()
                .trim(from: 0, to: progress.ratio)
                .stroke(
                    progress.state == .overdue ? Color.orange : Color.accentColor,
                    style: StrokeStyle(lineWidth: 6, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            Image(systemName: progress.state == .achieved ? "checkmark" : "target")
                .font(.caption)
        }
        .accessibilityHidden(true)
    }
}

struct SavingsGoalEditorView: View {
    let goal: SavingsGoalModel?
    @Environment(SavingsGoalViewModel.self) private var vm
    @AppStorage("notificationsEnabled", store: .appGroup) private var notificationsEnabled = true
    @Environment(\.dismiss) private var dismiss

    @State private var draft = SavingsGoalModel()
    @State private var name = ""
    @State private var target = ""
    @State private var perPeriod = ""
    @State private var saved = ""

    private let icons = ["target", "house", "car", "airplane", "gift", "graduationcap"]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(String.appLocalized("Goal name"), text: $name)
                    Picker(String.appLocalized("Icon"), selection: $draft.icon) {
                        ForEach(icons, id: \.self) { icon in
                            Label(icon, systemImage: icon).tag(icon)
                        }
                    }
                }
                Section {
                    Picker(String.appLocalized("Mode"), selection: $draft.mode) {
                        Text(String.appLocalized("Fixed amount")).tag(SavingsGoalMode.fixedAmount)
                        Text(String.appLocalized("Flexible")).tag(SavingsGoalMode.flexible)
                    }
                }
                if draft.mode == .fixedAmount {
                    Section {
                        TextField("0", text: $perPeriod)
                            #if os(iOS)
                            .keyboardType(.decimalPad)
                            #endif
                    } header: {
                        Text(String.appLocalized("Amount per period"))
                    }
                    Section {
                        Stepper(String.appFormatted("Periods: %lld", draft.periods),
                                value: $draft.periods, in: 1...240)
                        Stepper(String.appFormatted("Months per period: %lld", draft.periodMonths),
                                value: $draft.periodMonths, in: 1...12)
                        DatePicker(String.appLocalized("Start date"), selection: $draft.startDate,
                                   displayedComponents: .date)
                    }
                } else {
                    Section {
                        TextField("0", text: $target)
                            #if os(iOS)
                            .keyboardType(.decimalPad)
                            #endif
                    } header: {
                        Text(String.appLocalized("Target amount"))
                    }
                    Section {
                        DatePicker(String.appLocalized("Start date"), selection: $draft.startDate,
                                   displayedComponents: .date)
                        DatePicker(String.appLocalized("Deadline"), selection: $draft.deadline,
                                   displayedComponents: .date)
                    }
                }
                Section {
                    TextField("0", text: $saved)
                        #if os(iOS)
                        .keyboardType(.decimalPad)
                        #endif
                } header: {
                    Text(String.appLocalized("Saved so far"))
                }
                Section {
                    Picker(String.appLocalized("Linked card"), selection: $draft.linkedAccountID) {
                        Text(String.appLocalized("None (independent goal)"))
                            .tag(nil as UUID?)
                        ForEach(vm.accounts) { account in
                            Text(account.wrappedName).tag(account.id as UUID?)
                        }
                    }
                    Toggle(String.appLocalized("Use card balance as saved amount"),
                           isOn: $draft.useAccountBalance)
                        .disabled(draft.linkedAccountID == nil)
                    Toggle(String.appLocalized("Notify me when reached"),
                           isOn: $draft.notifyOnAchievement)
                }
                if let message = vm.message {
                    Section { Text(message).foregroundStyle(.red) }
                }
                if goal != nil {
                    Section {
                        Button(String.appLocalized("Delete goal"), role: .destructive) {
                            if let goal { vm.remove(goal) }
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(goal == nil
                             ? String.appLocalized("New goal")
                             : String.appLocalized("Edit goal"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String.appLocalized("Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String.appLocalized("Save")) { save() }
                }
            }
            .onAppear {
                vm.load()
                if let goal {
                    draft = goal
                    name = goal.name
                    target = number(goal.targetAmount)
                    perPeriod = number(goal.amountPerPeriod)
                    saved = number(goal.savedAmount)
                }
            }
        }
    }


    private func number(_ value: Double) -> String {
        value == 0 ? "" : String(format: "%.2f", value)
    }

    private func save() {
        var copy = draft
        copy.name = name
        copy.targetAmount = Double(target.replacingOccurrences(of: ",", with: ".")) ?? 0
        copy.amountPerPeriod = Double(perPeriod.replacingOccurrences(of: ",", with: ".")) ?? 0
        copy.savedAmount = Double(saved.replacingOccurrences(of: ",", with: ".")) ?? 0
        if draft.mode == .fixedAmount {
            copy.targetAmount = 0
        } else {
            copy.amountPerPeriod = 0
            copy.periods = 0
        }
        Task {
            if await vm.upsert(copy, notificationsEnabled: notificationsEnabled), vm.message == nil {
                dismiss()
            }
        }
    }
}
