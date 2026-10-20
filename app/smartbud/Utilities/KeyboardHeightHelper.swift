//
//  KeyboardHeightHelper.swift
//  smartbud
//
//  Created by Iorest on 16/5/22.
//
//  Tracks the soft-keyboard height via Foundation's `NotificationCenter`
//  async sequence. Migrated off the legacy closure-based
//  `NotificationCenter.publisher(for:)` (which required `import Combine`)
//  to the iOS 15+ `notifications(named:)` AsyncSequence consumed inside
//  a `.task` modifier — automatically cancelled when the view disappears.
//

import Foundation
import SwiftUI
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

extension Notification {
    var keyboardHeight: CGFloat {
        #if os(macOS)
        return 0
        #else
        return (userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect)?.height ?? 0
        #endif
    }
}

#if !os(macOS)
extension UIApplication {
}
#endif

struct KeyboardAwareModifier: ViewModifier {
    @AppStorage("keyboard", store: .appGroup) var savedKeyboardHeight: Double = 291
    @State private var isKeyboardVisible = false

    func body(content: Content) -> some View {
        #if os(macOS)
        content
        #else
        content
            .padding(.bottom, isKeyboardVisible ? max(0, savedKeyboardHeight) : 0)
            .animation(.easeOut(duration: 0.25), value: isKeyboardVisible)
            .task {
                // Two parallel async loops: keyboardWillShow updates the visible
                // height and persists it; keyboardWillHide zeros it. `TaskGroup`
                // gives both loops structured-concurrency cancellation when the
                // modifier goes away (the legacy `async { … }` inside `.task`
                // is deprecated and was replaced by `Task.init`). Each child
                // dispatches back to the main actor before mutating the
                // view-model state, since the async loops run on a generic
                // executor.
                await withTaskGroup(of: Void.self) { group in
                    group.addTask {
                        for await note in NotificationCenter
                            .default
                            .notifications(named: UIResponder.keyboardWillShowNotification) {
                            let height = note.keyboardHeight
                            if height > 200 {
                                await MainActor.run {
                                    isKeyboardVisible = true
                                    savedKeyboardHeight = height - 20
                                }
                            }
                        }
                    }
                    group.addTask {
                        for await _ in NotificationCenter
                            .default
                            .notifications(named: UIResponder.keyboardWillHideNotification) {
                            await MainActor.run { isKeyboardVisible = false }
                        }
                    }
                }
            }
        #endif
    }
}

extension View {
    func keyboardAwareHeight() -> some View {
        ModifiedContent(content: self, modifier: KeyboardAwareModifier())
    }
}
