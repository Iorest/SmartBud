//
//  ExpenditureWidget.swift
//  ExpenditureWidget
//
//  Created by Iorest on 25/7/22.
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
