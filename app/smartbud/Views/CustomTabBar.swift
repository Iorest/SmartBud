//
//  CustomTabBar.swift
//  smartbud
//
//  Shared button styles. The custom tab bar was removed in favour of the
//  native TabView (see HomeView); only `MyButtonStyle` (floating add button)
//  and `BouncyButton` remain.
//

import Foundation
import SwiftUI
import SwiftData

struct MyButtonStyle: ButtonStyle {
    func makeBody(configuration: Self.Configuration) -> some View {
        configuration.label
            .font(.system(size: 26, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 58, height: 58)
            .background(
                Circle()
                    .fill(Theme.Brand.accent)
            )
            .shadow(color: Color.black.opacity(0.25), radius: 6, x: 0, y: 3)
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct BouncyButton: ButtonStyle {
    var duration: Double
    var scale: Double

    public func makeBody(configuration: Self.Configuration) -> some View {
        return configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .animation(.easeOut(duration: duration), value: configuration.isPressed)
    }
}

