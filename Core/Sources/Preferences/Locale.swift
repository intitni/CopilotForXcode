import Foundation

public extension Locale {
    static var availableLocales: [Locale] {
        Locale.availableIdentifiers.compactMap(Locale.init).reduce(into: []) { (locales, locale) in
            if !locales.contains(where: { $0.languageCode == locale.languageCode }) {
                locales.append(locale)
            }
        }.sorted(by: { $0.languageName < $1.languageName })
    }

    var languageName: String {
        localizedString(forLanguageCode: languageCode ?? "") ?? ""
    }
}
