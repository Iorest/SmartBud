//
//  WidgetConfigurationIntents.swift
//  smartbud
//
//  WidgetConfigurationIntent definitions for the four configurable widgets.
//  Replaces the legacy `WidgetConfiguration.intentdefinition` and the
//  `BudgetIntent` INExtension-based IntentHandler. AppEntity reuse comes
//  from `ShortcutsEntities.swift` (BudgetEntity + BudgetQuery), so the
//  budget picker follows the device's current book; widget data filters on
//  the same book when it renders.
//

import AppIntents
import WidgetKit

struct BudgetWidgetConfigurationIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Budget Widget"
    static let description = IntentDescription("Select a budget to monitor.")

    @Parameter(title: "Budget")
    var budget: BudgetEntity?
}

struct InsightsWidgetConfigurationIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Insights Widget"
    static let description = IntentDescription("Configure your insights view.")

    @Parameter(title: "Time Period", default: .week)
    var duration: InsightsTimePeriod

    @Parameter(title: "Type", default: .expenses)
    var income: Income
}

struct RecentWidgetConfigurationIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Recent Widget"
    static let description = IntentDescription("Configure your recent transactions view.")

    @Parameter(title: "Time Period", default: .week)
    var duration: TimePeriod

    @Parameter(title: "Insights Type", default: .expense)
    var insightsType: InsightsType
}
