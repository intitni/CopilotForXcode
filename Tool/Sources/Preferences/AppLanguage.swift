import Foundation

/// The languages this build ships localizations for.
///
/// `Bundle` picks a localization from `AppleLanguages`, so an in-app choice has to be mirrored into
/// the process' own defaults before the first localized lookup happens. Every executable that shows
/// text does that in ``AppLanguage/applyPreferredLanguage()`` at the very start of its launch.
public enum AppLanguage: String, CaseIterable, Codable, Equatable {
    /// Follow the languages configured in System Settings.
    case system = ""
    case english = "en"
    case simplifiedChinese = "zh-Hans"
    case traditionalChinese = "zh-Hant"

    /// The name of the language, always written in that language.
    public var displayName: String {
        switch self {
        case .system: return NSLocalizedString("Follow System", comment: "App language option")
        case .english: return "English"
        case .simplifiedChinese: return "简体中文"
        case .traditionalChinese: return "繁體中文"
        }
    }
}

public extension AppLanguage {
    private static let appleLanguagesKey = "AppleLanguages"

    /// Mirrors the shared language preference into this process' `AppleLanguages` override.
    ///
    /// Call this before any localized string is read. It is cheap and idempotent, so processes that
    /// cannot pin down a single earliest moment may call it more than once.
    static func applyPreferredLanguage() {
        let preference = UserDefaults.shared.value(for: \.appLanguage)
        let standard = UserDefaults.standard
        let existing = standard.array(forKey: appleLanguagesKey) as? [String]

        guard !preference.isEmpty else {
            // Removing the app-level override hands the choice back to System Settings.
            if existing != nil {
                standard.removeObject(forKey: appleLanguagesKey)
            }
            return
        }

        guard existing != [preference] else { return }
        standard.set([preference], forKey: appleLanguagesKey)
    }
}
