//
//  SettingsSubviewModifier.swift
//  dime
//
//  Created by Rafael Soh on 5/11/23.
//

import Foundation
import SwiftUI

struct SettingsSubviewModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .navigationBarBackButtonHidden(true)
            .toolbar(.hidden, for: .navigationBar)
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            // Settings is wrapped in `NavigationView`, which does not pass
            // through the parent's `AppGlassBackground`. Each subview gets its
            // own gradient here so the `glassCard` / `glassChip` surfaces
            // have colour to refract.
            .background(AppGlassBackground())
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }
}
