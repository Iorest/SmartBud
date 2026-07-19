//
//  GetInsightsIntent.swift
//  dime
//
//  Created by Rafael Soh on 5/8/23.
//

import AppIntents
import Foundation
import SwiftUI

struct GetInsightsIntent: AppIntent {
    static let title: LocalizedStringResource = "Get Insights"

    static let description =
        IntentDescription(LocalizedStringResource("Extracts your total expenditure or income for a particular time period"))

    @Parameter(title: LocalizedStringResource("Type"), description: LocalizedStringResource("Type of Data"), requestValueDialog: IntentDialog(LocalizedStringResource("Which of the following would you like to extract?")))
    var type: ShortcutsInsightsType

    @Parameter(title: LocalizedStringResource("Time Frame"), description: LocalizedStringResource("Time Frame of Data"), requestValueDialog: IntentDialog(LocalizedStringResource("Over what time frame would you like to consider?")))
    var timeframe: ShortcutsInsightsTimeFrame

    @Parameter(title: LocalizedStringResource("Category Filters"), description: LocalizedStringResource("Additional Category Filters"), requestValueDialog: IntentDialog(LocalizedStringResource("Which additional category filters do you want to impose?")))
    var incomeCategories: [IncomeCategoryEntity]?

    @Parameter(title: LocalizedStringResource("Category Filters"), description: LocalizedStringResource("Additional Category Filters"), requestValueDialog: IntentDialog(LocalizedStringResource("Which additional category filters do you want to impose?")))
    var expenseCategories: [ExpenseCategoryEntity]?

    @MainActor
    func perform() async throws -> some ReturnsValue<Double> & ShowsSnippetView & ProvidesDialog {
        let categories: [CategoryModel]
        let optionalIncome: Bool?
        let typeInt: Int

        switch type {
        case .net:
            categories = []
            optionalIncome = nil
            typeInt = 1
        case .income:
            if let unwrappedCategories = incomeCategories {
                categories = unwrappedCategories.compactMap { category in
                    CategoryViewModel.shared.findCategory(id: category.id)
                }
            } else {
                categories = []
            }

            optionalIncome = true
            typeInt = 2
        case .spent:
            if let unwrappedCategories = expenseCategories {
                categories = unwrappedCategories.compactMap { category in
                    CategoryViewModel.shared.findCategory(id: category.id)
                }
            } else {
                categories = []
            }
            optionalIncome = false
            typeInt = 3
        }

        let result = InsightsViewModel.shared.getShortcutInsights(type: typeInt, timeframe: timeframe.rawValue, optionalIncome: optionalIncome, categories: categories)

        return .result(value: result, dialog: IntentDialog(LocalizedStringResource("Here you go!"))) {
            ShortcutInsightsView(amount: result, type: type, timeframe: timeframe)
        }
    }

    static var parameterSummary: some ParameterSummary {
        Switch(\GetInsightsIntent.$type) {
            Case(ShortcutsInsightsType.net) {
                Summary("Calculate \(\.$type) for \(\.$timeframe)", table: "Localizable")
            }
            Case(ShortcutsInsightsType.income) {
                Summary("Calculate \(\.$type) for \(\.$timeframe)", table: "Localizable") {
                    \.$incomeCategories
                }
            }
            Case(ShortcutsInsightsType.spent) {
                Summary("Calculate \(\.$type) for \(\.$timeframe)", table: "Localizable") {
                    \.$expenseCategories
                }
            }
            DefaultCase {
                Summary("Calculate \(\.$type) for \(\.$timeframe)", table: "Localizable")
            }
        }
    }
}

enum ShortcutsInsightsTimeFrame: Int {
    case day = 1
    case week = 2
    case month = 3
    case year = 4
    case all = 5
}

extension ShortcutsInsightsTimeFrame: AppEnum {
    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        return TypeDisplayRepresentation(name: LocalizedStringResource("Time Frame"))
    }

    static let caseDisplayRepresentations: [ShortcutsInsightsTimeFrame: DisplayRepresentation] = [
        .day: DisplayRepresentation(title: LocalizedStringResource("today")),
        .week: DisplayRepresentation(title: LocalizedStringResource("this week")),
        .month: DisplayRepresentation(title: LocalizedStringResource("this month")),
        .year: DisplayRepresentation(title: LocalizedStringResource("this year")),
        .all: DisplayRepresentation(title: LocalizedStringResource("all time"))
    ]
}

enum ShortcutsInsightsType: String {
    case net, income, spent
}

extension ShortcutsInsightsType: AppEnum {
    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        return TypeDisplayRepresentation(name: LocalizedStringResource("Insights Type"))
    }

    static let caseDisplayRepresentations: [ShortcutsInsightsType: DisplayRepresentation] = [
        .net: DisplayRepresentation(title: LocalizedStringResource("net total")),
        .income: DisplayRepresentation(title: LocalizedStringResource("total income")),
        .spent: DisplayRepresentation(title: LocalizedStringResource("total expenditure"))
    ]
}

struct ShortcutInsightsView: View {
    let amount: Double
    let type: ShortcutsInsightsType
    let timeframe: ShortcutsInsightsTimeFrame

    @AppStorage("showCents", store: UserDefaults(suiteName: "group.com.rafaelsoh.dime")) var showCents: Bool = true

    @AppStorage("currency", store: UserDefaults(suiteName: "group.com.rafaelsoh.dime")) var currency: String = Locale.current.currency?.identifier ?? "USD"

    var leftText: String.LocalizationValue {
        switch type {
        case .net:
            return "Net total"
        case .income:
            return "Earned"
        case .spent:
            return "Spent"
        }
    }

    var rightText: String.LocalizationValue {
        switch timeframe {
        case .day:
            return "today"
        case .week:
            return "this week"
        case .month:
            return "this month"
        case .year:
            return "this year"
        case .all:
            return "all time"
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

        return numberFormatter.string(from: NSNumber(value: amount)) ?? "$0"
    }

    var body: some View {
        VStack(spacing: 2) {
            Text("\(leftText) \(rightText)")
                .font(.system(size: 17, weight: .medium, design: .rounded))
                .foregroundStyle(Color.SubtitleText)

            Text(amountString)
                .font(.system(size: 32, weight: .medium, design: .rounded))
                .lineLimit(1)
        }
        .padding(20)
    }
}
