//
//  SettingsSubviewModifier.swift
//  smartbud
//
//  Created by Iorest on 5/11/23.
//

import Foundation
import SwiftUI

struct SettingsSubviewModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .hiddenNavigationBackButton()
            .hiddenNavigationBar()
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            // Pushed subviews sit on the navigation stack's opaque default
            // background, not the tab's `AppBackground`. Without this the
            // page is pure white and every white card disappears.
            .background(AppBackground())
    }
}
