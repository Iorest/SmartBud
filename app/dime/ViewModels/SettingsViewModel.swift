import SwiftUI
import SwiftData

@MainActor
final class SettingsViewModel: ObservableObject {
    static let shared = SettingsViewModel()
    private let repo = DataRepository.shared

    func fetchAllTransactions() -> [TransactionModel] {
        repo.fetch(TransactionModel.self, sort: [SortDescriptor(\.date, order: .reverse)])
    }

    func eraseAllData() {
        repo.deleteAll()
    }

    // MARK: - In-app language

    /// Supported in-app language codes. `nil` means "follow system".
    static let supportedLanguageCodes: [String] = ["", "en", "zh-Hans", "zh-Hant"]

    /// Human-readable display names for `supportedLanguageCodes`, looked up in
    /// the current locale. Used by the language picker — no flag emoji here, by
    /// design: the language identification in this app is done via the colored
    /// "logo" icon on the Settings row, not by country flags.
    func displayName(for code: String) -> String {
        switch code {
        case "":        return String(localized: "System")
        case "en":      return String(localized: "English")
        case "zh-Hans": return String(localized: "简体中文")
        case "zh-Hant": return String(localized: "繁體中文")
        default:        return code
        }
    }

    /// Convert a stored language code into a `Locale` override.
    /// Returns `nil` for the empty (system) case so SwiftUI falls back to the
    /// device locale.
    func locale(for code: String) -> Locale? {
        guard !code.isEmpty else { return nil }
        return Locale(identifier: code)
    }
}
