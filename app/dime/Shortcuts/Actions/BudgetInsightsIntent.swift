//
//  BudgetInsightsIntent.swift
//  dime
//
//  Created by Rafael Soh on 6/8/23.
//

import AppIntents
import Foundation
import SwiftUI

struct BudgetIntent: AppIntent {
    static let title: LocalizedStringResource = "Get Budget Insights"

    static let description =
        IntentDescription(LocalizedStringResource("Extract leftover amount for a particular budget"))

    @Parameter(title: LocalizedStringResource("Budget Type"), requestValueDialog: IntentDialog(LocalizedStringResource("What budget type would you like to extract insights from?")))
    var type: ShortcutsBudgetsType

    @Parameter(title: LocalizedStringResource("Category Budget"), requestValueDialog: IntentDialog(LocalizedStringResource("Select a categorical budget.")))
    var budget: BudgetEntity?

    @MainActor
    func perform() async throws -> some ReturnsValue<Double> & ShowsSnippetView & ProvidesDialog {
        if type == .category && budget == nil {
            throw $budget.needsValueError()
        }

        var amount: Double = 0
        var budgetType: Int = 0

        switch type {
        case .overall:
            if let mainBudget = BudgetViewModel.shared.getMainBudget() {
                amount = BudgetViewModel.shared.leftoverOverall(mainBudget)
                budgetType = mainBudget.type
            }
        case .category:
            if let unwrappedBudget = budget {
                if let categoryBudget = BudgetViewModel.shared.findBudget(id: unwrappedBudget.id) {
                    amount = BudgetViewModel.shared.leftover(categoryBudget)
                    budgetType = categoryBudget.type
                }
            }
        }

        return .result(value: amount, dialog: IntentDialog(LocalizedStringResource("Here you go!"))) {
            ShortcutBudgetView(amount: amount, type: budgetType)
        }
    }

    static var parameterSummary: some ParameterSummary {
        Switch(\BudgetIntent.$type) {
            Case(ShortcutsBudgetsType.category) {
                Summary("Calculate leftover amount for the \(\.$budget) \(\.$type)", table: "Localizable")
            }
            Case(ShortcutsBudgetsType.overall) {
                Summary("Calculate leftover amount for the \(\.$type)", table: "Localizable")
            }
            DefaultCase {
                Summary("Calculate leftover amount for the \(\.$type)", table: "Localizable")
            }
        }
    }
}

enum ShortcutsBudgetsType: String {
    case overall, category
}

extension ShortcutsBudgetsType: AppEnum {
    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        return TypeDisplayRepresentation(name: LocalizedStringResource("Budget Type"))
    }

    static let caseDisplayRepresentations: [ShortcutsBudgetsType: DisplayRepresentation] = [
        .overall: DisplayRepresentation(title: LocalizedStringResource("overall budget")),
        .category: DisplayRepresentation(title: LocalizedStringResource("categorical budget"))
    ]
}

struct ShortcutBudgetView: View {
    let amount: Double
    let type: Int

    @AppStorage("showCents", store: UserDefaults(suiteName: "group.com.rafaelsoh.dime")) var showCents: Bool = true

    @AppStorage("currency", store: UserDefaults(suiteName: "group.com.rafaelsoh.dime")) var currency: String = Locale.current.currency?.identifier ?? "USD"

    var budgetType: String {
        switch type {
        case 1:
            return String(localized: "today")
        case 2:
            return String(localized: "this week")
        case 3:
            return String(localized: "this month")
        case 4:
            return String(localized: "this year")
        default:
            return "this week"
        }
    }

    var amountString: String {
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .currency
        numberFormatter.currencyCode = currency

        if showCents {
            numberFormatter.maximumFractionDigits = 2
        } else {
            numberFormatter.maximumFractionDigits = 0
        }

        return numberFormatter.string(from: NSNumber(value: abs(amount))) ?? "$0"
    }

    var body: some View {
        VStack(spacing: 2) {
            Text(amountString)
                .font(.system(size: 32, weight: .medium, design: .rounded))
                .lineLimit(1)

            if amount > 0 {
                Text(String(localized: "left \(budgetType)"))
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(Color.SubtitleText)
            } else {
                Text(String(localized: "over \(budgetType)"))
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(Color.SubtitleText)
            }
        }
        .padding(20)
    }
}
