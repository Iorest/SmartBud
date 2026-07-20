//
//  WidgetEnums.swift
//  smartbud
//
//  AppEnum types backing widget configuration intents. Int raw values
//  mirror the legacy `WidgetConfiguration.intentdefinition` so internal
//  widget switch/case code keeps working unchanged.
//

import AppIntents

enum TimePeriod: Int, AppEnum {
    case unknown = 0
    case day = 1
    case week = 2
    case month = 3
    case year = 4

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Time Period"

    static let caseDisplayRepresentations: [TimePeriod: DisplayRepresentation] = [
        .unknown: "Unknown",
        .day: "Day",
        .week: "Week",
        .month: "Month",
        .year: "Year"
    ]
}

enum InsightsTimePeriod: Int, AppEnum {
    case unknown = 0
    case week = 1
    case month = 2
    case year = 3

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Time Period"

    static let caseDisplayRepresentations: [InsightsTimePeriod: DisplayRepresentation] = [
        .unknown: "Unknown",
        .week: "Week",
        .month: "Month",
        .year: "Year"
    ]
}

enum InsightsType: Int, AppEnum {
    case unknown = 0
    case net = 1
    case income = 2
    case expense = 3

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Insights Type"

    static let caseDisplayRepresentations: [InsightsType: DisplayRepresentation] = [
        .unknown: "Unknown",
        .net: "Net Total",
        .income: "Total Income",
        .expense: "Total Expenditure"
    ]
}

enum Income: Int, AppEnum {
    case unknown = 0
    case income = 1
    case expenses = 2

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Income"

    static let caseDisplayRepresentations: [Income: DisplayRepresentation] = [
        .unknown: "Unknown",
        .income: "Income",
        .expenses: "Expenses"
    ]
}
