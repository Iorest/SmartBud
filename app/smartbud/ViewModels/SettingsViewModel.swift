import SwiftUI
import SwiftData
import Observation

@MainActor
@Observable
final class SettingsViewModel{
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
        case "":        return String.appLocalized("System")
        case "en":      return String.appLocalized("English")
        case "zh-Hans": return String.appLocalized("Simplified Chinese")
        case "zh-Hant": return String.appLocalized("Traditional Chinese")
        default:        return code
        }
    }

    // MARK: - Pro card

    /// Subtitle shown in the PRO section of `SettingsView`. Localized so it
    /// follows the in-app language switch in `SettingsLanguageView`.
    var proCardSubtitle: String {
        String.appLocalized("Unlock all Pro features")
    }
}
