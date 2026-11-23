//
//  NewBudgetView+Content.swift
//  smartbud
//
import SwiftUI
import SwiftData

extension BrandNewBudgetView {

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                    Button {
                        if showBackButton {
                            AppMotion.withAnimation(.interactiveSpring(response: 0.6, dampingFraction: 0.8, blendDuration: 0.8)) {
                                if progress > 1 {
                                    progress = 1
                                }
                            }
                        } else if hasUnsavedInput {
                            showDiscardConfirm = true
                        } else {
                            dismiss()
                        }
                    } label: {
                        Image(systemName: showBackButton ? "chevron.left" : "xmark")
                            .font(.callout.weight(.semibold))

                            .foregroundStyle(Color.SubtitleText)
                            .padding(8)
                            .background(Color.SecondaryBackground, in: Circle())
                    }
                    .accessibilityLabel(showBackButton ? String.appLocalized("Back") : String.appLocalized("Close"))
                    .contentTransition(.symbolEffect(.replace.downUp.wholeSymbol))

                Spacer()

                ProgressView(value: progress == 1 ? 0.5 : 1)
                    .frame(width: 72)
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay {
                if showToast {
                    HStack(spacing: 6.5) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.AlertRed)

                        Text(toastMessage)
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(Color.AlertRed)
                    }
                    .padding(8)
                    .background(
                        Color.AlertRed.opacity(0.23),
                        in: RoundedRectangle(cornerRadius: SBRadius.chip, style: .continuous)
                    )
                    .appTransition(AnyTransition.opacity.combined(with: .move(edge: .top)))
                    .frame(width: 250)
                }
            }
            .padding(.bottom, 50)
            .animation(.easeInOut, value: showBackButton)

            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(instructions[progress == 1 ? 0 : 1].title)
                        .foregroundStyle(Color.PrimaryText)
                        .font(.title2.weight(.semibold))

                    Spacer()
                }
                .frame(maxWidth: .infinity)

                Text(instructions[progress == 1 ? 0 : 1].subtitle)
                    .foregroundStyle(Color.SubtitleText)
                    .font(.body.weight(.medium))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: labelHeight, alignment: .top)

            if progress == 1 {
                budgetDetails
            } else {
                amountPage
            }

            if progress == 1 {
                Button {
                    continueToAmount()
                } label: {
                    Text(String.appLocalized("Continue"))
                        .font(.body.weight(.semibold))
                        .padding(.vertical, 13)
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(Color.LightIcon)
                        .background(
                            Color.DarkBackground,
                            in: RoundedRectangle(cornerRadius: SBRadius.card, style: .continuous)
                        )
                }
                .buttonStyle(BouncyButton(duration: 0.2, scale: 0.8))
                .accessibilityIdentifier(AccessibilityID.budgetContinue)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

        .appBackground()
        .guardModalDismiss(isDirty: hasUnsavedInput)
        .confirmationDialog(
            String.appLocalized("Discard unsaved changes?"),
            isPresented: $showDiscardConfirm
        ) {
            Button(String.appLocalized("Discard"), role: .destructive) { dismiss() }
            Button(String.appLocalized("Cancel"), role: .cancel) {}
        }
        .onAppear {
            // Sync the pad VM with the AppStorage flags on first appearance.
            // Subsequent changes are picked up by the `onChange` below.
            padVM.numberEntryType = numberEntryType
            if let edited = toEditBudget {
                selectedCategory = edited.category
                applyEditorState(type: edited.type, startDate: edited.startDate, amount: edited.amount)
            } else if let edited = toEditMainBudget {
                applyEditorState(type: edited.type, startDate: edited.startDate, amount: edited.amount)
            } else {
                chosenDayWeek = firstWeekday
                chosenDayMonth = firstDayOfMonth
            }
        }
        .sheet(isPresented: $showingCategoryView) {
                NewCategoryAlert(income: Binding.constant(false), bottomSpacers: false, budgetMode: true)
                    .presentationDetents([.medium, .large])
        }
        .animation(.easeOut(duration: 0.2), value: showToast)
        .onChange(of: numberEntryType) { _, new in
            padVM.numberEntryType = new
        }
        .onChange(of: hapticType) { _, new in
            padVM.hapticType = new
        }
        .onChange(of: showToast) { _, newValue in
            if newValue {
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(2))
                    showToast = false
                }
            }
        }
        .sensoryFeedback(.error, trigger: errorHaptic)
        .sensoryFeedback(.impact(weight: .light), trigger: lightHaptic)
    }

    /// Editing keeps the original anchor unless the period type changed.
    func resolvedStartDate(budgetType: Int) -> Date {
        let timeFrameInt: Int
        switch budgetTimeFrame {
        case .day: timeFrameInt = 0
        case .week: timeFrameInt = 1
        case .month: timeFrameInt = 2
        case .year: timeFrameInt = 3
        }
        let computed = budgetVM.computeStartDate(
            timeFrameRaw: timeFrameInt,
            chosenDayWeek: chosenDayWeek,
            chosenDayMonth: chosenDayMonth,
            chosenDayYear: chosenDayYear
        )
        return BudgetAnchor.startDate(
            original: toEditBudget?.startDate ?? toEditMainBudget?.startDate,
            oldType: toEditBudget?.type ?? toEditMainBudget?.type ?? budgetType,
            newType: budgetType,
            computed: computed
        )
    }

    /// Saves an in-place edit. Returns `false` when this is a new budget.
    func saveExistingBudget(amount: Double, startDate: Date, budgetType: Int) -> Bool {
        if let edited = toEditBudget {
            // A budget without a category (legacy row) can only be saved once
            // one is picked. Silently closing here looked like a save but
            // dropped the amount the user just typed.
            guard let category = selectedCategory ?? edited.category else {
                errorHaptic &+= 1
                showToast = true
                toastMessage = String.appLocalized("Missing Category")
                return true
            }
            budgetVM.update(edited, amount: amount, startDate: startDate,
                            type: budgetType, category: category)
            padVM.submit()
            dismiss()
            return true
        }
        if let edited = toEditMainBudget {
            budgetVM.updateMain(edited, amount: amount, startDate: startDate, type: budgetType)
            padVM.submit()
            dismiss()
            return true
        }
        return false
    }

    func createBudget(amount: Double, startDate: Date, budgetType: Int) {
        if categoryBudget, let category = selectedCategory {
            _ = budgetVM.create(amount: amount, startDate: startDate,
                                type: budgetType, category: category)
        } else {
            _ = budgetVM.createMain(amount: amount, startDate: startDate, type: budgetType)
        }
        padVM.submit()
        dismiss()
    }

    func submit() {
        let amount = padVM.price
        guard amount > 0 else {
            errorHaptic &+= 1
            showToast = true
            toastMessage = String.appLocalized("Missing Amount")
            return
        }

        lightHaptic &+= 1
        let budgetType = getBudgetTypeInteger(budgetTimeFrame)
        let startDate = resolvedStartDate(budgetType: budgetType)

        if saveExistingBudget(amount: amount, startDate: startDate, budgetType: budgetType) {
            return
        }
        createBudget(amount: amount, startDate: startDate, budgetType: budgetType)
    }
}
