//
//  ProUpsell.swift
//  smartbud
//
//  Presents the Pro screen from a gated control. Lives outside `ProAccess` so
//  the access rule stays UI-free and can be compiled into the test target.
//

import SwiftUI

extension View {
    func proUpsell(isPresented: Binding<Bool>) -> some View {
        sheet(isPresented: isPresented) {
            NavigationStack { SettingsProView() }
        }
    }
}
