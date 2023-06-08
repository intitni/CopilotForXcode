import Foundation

public extension Locale {
    static var availableLocalizedLocales: [String] {
        let localizedLocales = Locale.isoLanguageCodes.compactMap {
            Locale(identifier: "en-US").localizedString(forLanguageCode: $0)
        }
        .sorted()
        return localizedLocales
    }

    var languageName: String {
        localizedString(forLanguageCode: languageCode ?? "") ?? ""
    }
}
