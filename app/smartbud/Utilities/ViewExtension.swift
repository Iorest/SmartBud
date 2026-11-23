//
//  ViewExtension.swift
//  smartbud
//
//  Created by Iorest on 16/5/22.
//

import Foundation
import SwiftUI
#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

/// Single source of truth for "Reduce Motion". Reads the system setting
/// directly so it works inside `withAnimation` closures as well as SwiftUI
/// view bodies (where `@Environment(\.accessibilityReduceMotion)` is available).
/// Per design.md §9.0: drop position/scale motion, keep opacity fades.
enum AppMotion {
    static var isReduced: Bool {
        #if os(macOS)
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        #elseif os(iOS)
        UIAccessibility.isReduceMotionEnabled
        #else
        false
        #endif
    }

    /// Returns `nil` (no animation) when the user asked to reduce motion.
    static func animation(_ base: Animation?) -> Animation? {
        isReduced ? nil : base
    }

    /// Collapses a move/scale transition to a plain fade when reducing motion.
    static func transition(_ base: AnyTransition) -> AnyTransition {
        isReduced ? .opacity : base
    }

    /// `withAnimation` equivalent that no-ops the animation under Reduce Motion
    /// while still running the state change.
    @MainActor
    static func withAnimation<Result>(
        _ animation: Animation? = .default,
        _ body: () throws -> Result
    ) rethrows -> Result {
        if isReduced { return try body() }
        return try SwiftUI.withAnimation(animation, body)
    }
}

extension View {
    /// Drop position/scale movement under Reduce Motion but keep fades.
    func appTransition(_ transition: AnyTransition) -> some View {
        self.transition(AppMotion.transition(transition))
    }

    /// Gate a value-driven animation on Reduce Motion (for the few scale/
    /// geometry animations that are not attached to a transition).
    func motionAnimation<V: Equatable>(_ animation: Animation?, value: V) -> some View {
        self.animation(AppMotion.animation(animation), value: value)
    }

    /// TELE-25: expand a compact icon control's hit region to the 44×44pt
    /// minimum from design.md §9.0 without changing its visual size.
    func hitTarget44() -> some View {
        self
            .contentShape(Rectangle())
            .frame(minWidth: 44, minHeight: 44)
    }

    /// TELE-25: block the accidental swipe-to-dismiss path on a modal while it
    /// holds unsaved input. Explicit Cancel/Done buttons still call `dismiss()`
    /// — `interactiveDismissDisabled` only removes the gesture.
    func guardModalDismiss(isDirty: Bool) -> some View {
        self.interactiveDismissDisabled(isDirty)
    }
}

extension View {
    func hideKeyboard() {
        #if os(macOS)
        NSApp.keyWindow?.makeFirstResponder(nil)
        #else
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        #endif
    }
}

extension View {
    func confettiOverlay(isActive: Binding<Bool>, particleCount: Int = 50) -> some View {
        modifier(ConfettiModifier(isActive: isActive, particleCount: particleCount))
    }
}

struct ConfettiModifier: ViewModifier {
    @Binding var isActive: Bool
    let particleCount: Int

    func body(content: Content) -> some View {
        content.overlay {
            if isActive {
                TimelineView(.animation) { timeline in
                    Canvas { context, size in
                        let now = timeline.date.timeIntervalSinceReferenceDate
                        let seed = Int(now * 20)

                        for particle in 0..<particleCount {
                            var rng = SeededRNG(seed: seed + particle)
                            let startX = rng.next() * size.width
                            let startY = rng.next() * size.height - 100
                            let progress = (rng.next() + sin(now * 3 + Double(particle))) * size.height
                            let angle = rng.next() * .pi * 2
                            let hue = rng.next()

                            let color = Color(hue: hue, saturation: 0.8, brightness: 0.9)
                            let rect = CGRect(
                                x: startX + cos(angle) * 30,
                                y: startY + progress,
                                width: 6 + rng.next() * 4,
                                height: 6 + rng.next() * 4
                            )
                            context.fill(Path(roundedRect: rect, cornerRadius: 2), with: .color(color))
                        }
                    }
                }
                .allowsHitTesting(false)
                .onAppear {
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(1500))
                        withAnimation(.easeOut(duration: 0.5)) {
                            isActive = false
                        }
                    }
                }
            }
        }
    }
}

private struct SeededRNG {
    var state: UInt64
    init(seed: Int) { state = UInt64(bitPattern: Int64(seed)) }
    mutating func next() -> CGFloat {
        state = state &* 6364136223846793005 &+ 1
        return CGFloat(state % 1000) / 1000.0
    }
}

extension View {
    /// `fullScreenCover` is iOS-only; macOS presents the same content as a
    /// sheet so dialogs stay inside the window.
    @ViewBuilder
    func fullScreenPresentation<Content: View>(
        isPresented: Binding<Bool>,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        #if os(macOS)
        sheet(isPresented: isPresented, onDismiss: onDismiss, content: content)
        #else
        fullScreenCover(isPresented: isPresented, onDismiss: onDismiss, content: content)
        #endif
    }

    @ViewBuilder
    func fullScreenPresentation<Item: Identifiable, Content: View>(
        item: Binding<Item?>,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: @escaping (Item) -> Content
    ) -> some View {
        #if os(macOS)
        sheet(item: item, onDismiss: onDismiss, content: content)
        #else
        fullScreenCover(item: item, onDismiss: onDismiss, content: content)
        #endif
    }

    /// The app draws its own back buttons; hide the platform chrome where it
    /// exists (iOS navigation bars; macOS has none in this hierarchy).
    @ViewBuilder
    func hiddenNavigationBar() -> some View {
        #if os(iOS)
        toolbar(.hidden, for: .navigationBar)
        #else
        self
        #endif
    }

    @ViewBuilder
    func hiddenNavigationBackButton() -> some View {
        #if os(iOS)
        navigationBarBackButtonHidden(true)
        #else
        self
        #endif
    }
}
