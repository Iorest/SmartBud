//
//  ExpenditureWidget.swift
//  ExpenditureWidget
//
//  Created by Iorest on 25/7/22.
//
//  The widget extension runs in its own process with its own
//  `Bundle.main` and its own UserDefaults. Install the same
//  `LanguageBundle` swizzle used by the main app so widget strings
//  (`String(localized: "in %@")` etc.) honour the in-app language pick
//  rather than the system locale. Without this, widgets would always
//  render in the device's language even when the user picked a
//  different one in `Settings → Language`.
//

import SwiftUI
import WidgetKit

@main
struct SmartBudWidgets: WidgetBundle {
    init() {
        LanguageBundleInstaller.install()
    }

    var body: some Widget {
        RecentExpenditureWidget()
        InsightsWidget()
        BudgetWidget()
        LockBudgetWidget()
        MainBudgetWidget()
        NewExpenseWidget()
    }
}
