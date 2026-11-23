//
//  ButtonStyles.swift
//  smartbud
//
//  Shared button styles. The old custom tab bar is gone (HomeView uses the
//  native TabView); only the floating add button and the press-scale style
//  remain here.
//

import SwiftUI

/// Subtle press-scale feedback for cards and chips.
struct BouncyButton: ButtonStyle {
    var duration: Double
    var scale: Double

    func makeBody(configuration: Self.Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .motionAnimation(.easeOut(duration: duration), value: configuration.isPressed)
    }
}
