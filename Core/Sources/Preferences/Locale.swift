import Foundation

public extension Locale {
    static var availableLocalizedLocales: [String] {
        var localizedLocales = Locale.availableIdentifiers.compactMap {
            Locale(identifier: $0).localizedString(forIdentifier: $0)
        }
        .sorted()
        localizedLocales.insert("", at: 0)
        return localizedLocales
    }

    var languageName: String {
        localizedString(forLanguageCode: languageCode ?? "") ?? ""
    }
}
