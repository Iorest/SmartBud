import SwiftUI
import SwiftData
import Observation

@MainActor
@Observable
final class SettingsViewModel {
    static let shared = SettingsViewModel()
    private let repo = DataRepository.shared

    /// "Erase All Data" — wipes local records AND the CloudKit zone
    /// for App Store Guideline 5.1.1(v) compliance. See
    /// `DataRepository.wipeEverything()` for the full path.
    func wipeAllData() async -> DataRepository.WipeOutcome {
        await repo.wipeEverything()
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
        case "":        return String.appLocalized(L10n.languageSystem)
        case "en":      return String.appLocalized(L10n.languageEnglish)
        case "zh-Hans": return String.appLocalized(L10n.languageSimplifiedChinese)
        case "zh-Hant": return String.appLocalized(L10n.languageTraditionalChinese)
        default:        return code
        }
    }

    // MARK: - Pro card

    /// Subtitle shown in the PRO section of `SettingsView`. Localized so it
    /// follows the in-app language switch in `SettingsLanguageView`.
    var proCardSubtitle: String {
        String.appLocalized(SettingsKey.proSubtitle)
    }
}
