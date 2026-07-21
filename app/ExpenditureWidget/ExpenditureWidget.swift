//
//  ExpenditureWidget.swift
//  ExpenditureWidget
//
//  Created by Iorest on 25/7/22.
//
//  The widget extension runs in its own process with its own
//  `Bundle.main` and its own UserDefaults. Each widget body sets
//  `.environment(\.locale, Locale.appLocale)` so that SwiftUI `Text("…")`
//  lookups honour the in-app language pick rather than the system
//  locale. Date formatters also use `Locale.appLocale`. The historical
//  `LanguageBundleInstaller.install()` Bundle swizzle is no longer called
//  here — see `LanguageBundle.swift` for why.
//

import SwiftUI
import WidgetKit

@main
struct SmartBudWidgets: WidgetBundle {
    var body: some Widget {
        RecentExpenditureWidget()
        InsightsWidget()
        BudgetWidget()
        LockBudgetWidget()
        MainBudgetWidget()
        NewExpenseWidget()
    }
}
