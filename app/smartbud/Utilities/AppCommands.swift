//
//  AppCommands.swift
//  smartbud
//
//  Menu-bar commands shared by the iOS and macOS targets. The actions come
//  from the view hierarchy through `focusedSceneValue`, so the commands stay
//  in sync with whichever tab is on screen.
//

import SwiftUI

// MARK: - Menu commands

/// Actions the view hierarchy publishes to the menu bar. Each is a closure so
/// the command reaches whatever state currently owns the screen.
struct NewTransactionAction: FocusedValueKey { typealias Value = () -> Void }
struct SelectTabAction: FocusedValueKey { typealias Value = (String) -> Void }
struct SearchLogAction: FocusedValueKey { typealias Value = () -> Void }

extension FocusedValues {
    var newTransaction: NewTransactionAction.Value? {
        get { self[NewTransactionAction.self] }
        set { self[NewTransactionAction.self] = newValue }
    }

    var selectTab: SelectTabAction.Value? {
        get { self[SelectTabAction.self] }
        set { self[SelectTabAction.self] = newValue }
    }

    var searchLog: SearchLogAction.Value? {
        get { self[SearchLogAction.self] }
        set { self[SearchLogAction.self] = newValue }
    }
}

#if os(macOS)
struct SmartBudCommands: Commands {
    @FocusedValue(\.newTransaction) private var newTransaction
    @FocusedValue(\.selectTab) private var selectTab
    @FocusedValue(\.searchLog) private var searchLog

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button(String.appLocalized("New Transaction")) {
                newTransaction?()
            }
            .keyboardShortcut("n", modifiers: .command)
            .disabled(newTransaction == nil)
        }

        CommandGroup(after: .textEditing) {
            Button(String.appLocalized("Search notes, categories, amounts")) {
                searchLog?()
            }
            .keyboardShortcut("f", modifiers: .command)
            .disabled(searchLog == nil)
        }

        CommandMenu(String.appLocalized("View")) {
            Button(String.appLocalized("Log")) { selectTab?("Log") }
                .keyboardShortcut("1", modifiers: .command)
            Button(String.appLocalized("Insights")) { selectTab?("Insights") }
                .keyboardShortcut("2", modifiers: .command)
            Button(String.appLocalized("Budget")) { selectTab?("Budget") }
                .keyboardShortcut("3", modifiers: .command)
            Button(String.appLocalized("Settings")) { selectTab?("Settings") }
                .keyboardShortcut("4", modifiers: .command)
        }
    }
}
#endif
