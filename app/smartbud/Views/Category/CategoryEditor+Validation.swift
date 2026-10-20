//
//  CategoryEditor+Validation.swift
//  smartbud
//
//  Validation feedback for the shared category editor.
//

import SwiftUI

extension CategoryEditor {
    /// Shows the toast for the current validation error and focuses the field
    /// the user has to fix.
    func presentValidationError() {
        errorHaptic &+= 1

        switch outcome {
        case .incomplete:
            toastTitle = String.appLocalized("Incomplete Entry")
            toastImage = "questionmark.app"
        case .missingEmoji:
            toastTitle = String.appLocalized("Missing Emoji")
            toastImage = "person.fill"
            focusedField = .emoji
        case .missingName:
            toastTitle = String.appLocalized("Missing Name")
            toastImage = "character.cursor.ibeam"
            focusedField = .name
        case .duplicate:
            toastTitle = String.appLocalized("Duplicate Found")
            toastImage = "externaldrive"
        case .duplicateEmoji:
            toastTitle = String.appLocalized("Duplicate Emoji")
            toastImage = "person.fill"
            focusedField = .emoji
        case .duplicateName:
            toastTitle = String.appLocalized("Duplicate Name")
            toastImage = "character.cursor.ibeam"
            focusedField = .name
        default:
            return
        }

        positive = false
        showToast = true
    }
}
