//
//  SettingsWeekStartView.swift
//  smartbud
//
//  Created by Iorest on 5/11/23.
//

import Foundation
import SwiftUI

struct SettingsWeekStartView: View {
    @AppStorage("firstWeekday", store: .appGroup)
    var firstWeekday: Int = 1
    @AppStorage("firstDayOfMonth", store: .appGroup)
    var firstDayOfMonth: Int = 1

    private var weekdaySymbols: [String] {
        var calendar = Calendar.current
        calendar.locale = Locale.appLocale
        return calendar.weekdaySymbols
    }

    var body: some View {
        Form {
            Section(String.appLocalized("Start of Week")) {
                Picker(String.appLocalized("Start of Week"), selection: $firstWeekday) {
                    ForEach(1...7, id: \.self) { index in
                        Text(weekdaySymbols[index - 1]).tag(index)
                    }
                }
            }

            Section(String.appLocalized("Start of Month")) {
                Picker(String.appLocalized("Start of Month"), selection: $firstDayOfMonth) {
                    ForEach(1...28, id: \.self) { day in
                        Text(day == 1
                             ? String.appLocalized("Start of month")
                             : String.appFormatted("%@ of month", "\(day)"))
                            .tag(day)
                    }
                }
            }
        }
        #if os(macOS)
        .formStyle(.grouped)
        #endif
        .navigationTitle(String.appLocalized("Time Frames"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}
