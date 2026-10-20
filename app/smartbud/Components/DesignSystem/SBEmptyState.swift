//
//  SBEmptyState.swift
//  smartbud
//
//  Wraps ContentUnavailableView so every empty screen looks the same and
//  always offers a next action.
//

import SwiftUI

struct SBEmptyState: View {
    let systemImage: String
    let title: String
    var message: String?
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: systemImage)
        } description: {
            if let message {
                Text(message)
            }
        } actions: {
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
            }
        }
    }
}
