//
//  KeyboardHeightHelper.swift
//  xpenz
//
//  Created by Rafael Soh on 16/5/22.
//
//  Tracks the soft-keyboard height via Foundation's `NotificationCenter`
//  async sequence. Migrated off the legacy closure-based
//  `NotificationCenter.publisher(for:)` (which required `import Combine`)
//  to the iOS 15+ `notifications(named:)` AsyncSequence consumed inside
//  a `.task` modifier — automatically cancelled when the view disappears.
//

import Foundation
import SwiftUI
import UIKit

extension Notification {
    var keyboardHeight: CGFloat {
        (userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect)?.height ?? 0
    }
}

extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content
    ) -> some View {
        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}

extension UIApplication {
    func endEditing() {
        sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

struct KeyboardAwareModifier: ViewModifier {
    @AppStorage("keyboard", store: UserDefaults(suiteName: "group.com.rafaelsoh.dime")) var savedKeyboardHeight: Double = 291
    var showToolbar: Bool
    @State private var isKeyboardVisible = false

    func body(content: Content) -> some View {
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
                        for await note in NotificationCenter.default.notifications(named: UIResponder.keyboardWillShowNotification) {
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
                        for await _ in NotificationCenter.default.notifications(named: UIResponder.keyboardWillHideNotification) {
                            await MainActor.run { isKeyboardVisible = false }
                        }
                    }
                }
            }
    }
}

extension View {
    func keyboardAwareHeight(showToolbar: Bool) -> some View {
        ModifiedContent(content: self, modifier: KeyboardAwareModifier(showToolbar: showToolbar))
    }
}
