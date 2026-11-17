//
//  SBToast.swift
//  smartbud
//
//  Inline validation toast shared by the transaction form and the category
//  editors. Each screen owns its own `showToast` flag and swaps this view in
//  where a control normally sits, so nothing floats above the content.
//

import SwiftUI

struct SBToast: View {
    let title: String
    let systemImage: String
    var positive: Bool = false

    private var tint: Color { positive ? Color.IncomeGreen : Color.AlertRed }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.semibold))

            Text(title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(tint.opacity(0.18),
                    in: RoundedRectangle(cornerRadius: SBRadius.chip, style: .continuous))
        .frame(maxWidth: 250)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(AccessibilityID.entryToast)
    }
}

extension SBToast {
    /// XCUITest's accessibility snapshots on a loaded CI runner can stall for
    /// tens of seconds (A3's first poll took 28 s after the tap), so neither
    /// the default 2 s window nor a 30 s one survives to the assertion.
    /// `-holdToasts` keeps the message up for ten minutes; the test dismisses
    /// the form itself. Product builds are unchanged.
    static var dismissalDuration: Duration {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-holdToasts") {
            return .seconds(600)
        }
        #endif
        return .seconds(2)
    }
}

extension View {
    /// Hides `isPresented` after `after`. The timer is tied to the flag's
    /// identity, so a second message restarts the window instead of being
    /// cut short by the previous message's timer.
    func sbToastDismissal(_ isPresented: Binding<Bool>,
                          after: Duration = .seconds(2)) -> some View {
        modifier(SBToastDismissalModifier(isPresented: isPresented, duration: after))
    }
}

private struct SBToastDismissalModifier: ViewModifier {
    @Binding var isPresented: Bool
    let duration: Duration

    func body(content: Content) -> some View {
        content.task(id: isPresented) {
            guard isPresented else { return }
            try? await Task.sleep(for: duration)
            guard !Task.isCancelled else { return }
            isPresented = false
        }
    }
}
