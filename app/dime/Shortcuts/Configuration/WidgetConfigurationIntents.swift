//
//  WidgetConfigurationIntents.swift
//  dime
//
//  WidgetConfigurationIntent definitions for the four configurable widgets.
//  Replaces the legacy `WidgetConfiguration.intentdefinition` and the
//  `BudgetIntent` INExtension-based IntentHandler. AppEntity reuse comes
//  from `ShortcutsEntities.swift` (BudgetEntity + BudgetQuery).
//

import AppIntents
import WidgetKit

@available(iOS 17, *)
struct BudgetWidgetConfigurationIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Budget Widget"
    static let description = IntentDescription("Select a budget to monitor.")

    @Parameter(title: "Budget")
    var budget: BudgetEntity?
}

@available(iOS 17, *)
struct InsightsWidgetConfigurationIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Insights Widget"
    static let description = IntentDescription("Configure your insights view.")

    @Parameter(title: "Time Period", default: .week)
    var duration: InsightsTimePeriod

    @Parameter(title: "Type", default: .expenses)
    var income: Income
}

@available(iOS 17, *)
struct RecentWidgetConfigurationIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Recent Widget"
    static let description = IntentDescription("Configure your recent transactions view.")

    @Parameter(title: "Time Period", default: .week)
    var duration: TimePeriod

    @Parameter(title: "Insights Type", default: .expense)
    var insightsType: InsightsType
}
