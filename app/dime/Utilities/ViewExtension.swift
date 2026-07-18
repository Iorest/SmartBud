//
//  ViewExtension.swift
//  xpenz
//
//  Created by Rafael Soh on 16/5/22.
//

import Foundation
import SwiftUI

#if canImport(UIKit)
    extension View {
        func hideKeyboard() {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
    }
#endif

extension View {
    @ViewBuilder func scrollEnabled(_ enabled: Bool) -> some View {
        if enabled {
            self
        } else {
            simultaneousGesture(DragGesture(minimumDistance: 0),
                                including: .all)
        }
    }

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

                        for i in 0..<particleCount {
                            var rng = SeededRNG(seed: seed + i)
                            let x = rng.next() * size.width
                            let y = rng.next() * size.height - 100
                            let progress = (rng.next() + sin(now * 3 + Double(i))) * size.height
                            let angle = rng.next() * .pi * 2
                            let hue = rng.next()

                            let color = Color(hue: hue, saturation: 0.8, brightness: 0.9)
                            let rect = CGRect(
                                x: x + cos(angle) * 30,
                                y: y + progress,
                                width: 6 + rng.next() * 4,
                                height: 6 + rng.next() * 4
                            )
                            context.fill(Path(roundedRect: rect, cornerRadius: 2), with: .color(color))
                        }
                    }
                }
                .allowsHitTesting(false)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
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

extension HorizontalAlignment {
    struct MoneySubtitle: AlignmentID {
        static func defaultValue(in d: ViewDimensions) -> CGFloat {
            d[.top]
        }
    }

    static let moneySubtitle = HorizontalAlignment(MoneySubtitle.self)
}

extension UINavigationController: @retroactive UIGestureRecognizerDelegate {
    override open func viewDidLoad() {
        super.viewDidLoad()
        interactivePopGestureRecognizer?.delegate = self
    }

    public func gestureRecognizerShouldBegin(_: UIGestureRecognizer) -> Bool {
        return viewControllers.count > 1
    }
}

@MainActor
class Utilities {
    @AppStorage("colourScheme") var selectedAppearance = 0
    var userInterfaceStyle: ColorScheme? = .dark

    func overrideDisplayMode() {
        var userInterfaceStyle: UIUserInterfaceStyle

        if selectedAppearance == 2 {
            userInterfaceStyle = .dark
        } else if selectedAppearance == 1 {
            userInterfaceStyle = .light
        } else {
            userInterfaceStyle = .unspecified
        }

        (UIApplication.shared.connectedScenes.first as?
            UIWindowScene)?.windows.first!.overrideUserInterfaceStyle = userInterfaceStyle
    }
}
