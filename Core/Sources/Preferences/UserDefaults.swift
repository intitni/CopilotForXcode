import Foundation
import Configs

public extension UserDefaults {
    static var shared = UserDefaults(suiteName: userDefaultSuiteName)!

    static func setupDefaultSettings() {
        shared.setupDefaultValue(for: \.quitXPCServiceOnXcodeAndAppQuit)
        shared.setupDefaultValue(for: \.realtimeSuggestionToggle)
        shared.setupDefaultValue(for: \.realtimeSuggestionDebounce)
        shared.setupDefaultValue(for: \.automaticallyCheckForUpdate)
        shared.setupDefaultValue(for: \.suggestionPresentationMode)
        shared.setupDefaultValue(for: \.widgetColorScheme)
        shared.setupDefaultValue(for: \.customCommands)
        shared.setupDefaultValue(for: \.runNodeWith, defaultValue: .env)
        shared.setupDefaultValue(for: \.openAIBaseURL, defaultValue: {
            guard let url = URL(string: shared.value(for: \.chatGPTEndpoint)) else { return "" }
            let scheme = url.scheme ?? "https"
            guard let host = url.host else { return "" }
            return "\(scheme)://\(host)"
        }() as String)
    }
}

public protocol UserDefaultsStorable {}

extension Int: UserDefaultsStorable {}
extension Double: UserDefaultsStorable {}
extension Bool: UserDefaultsStorable {}
extension String: UserDefaultsStorable {}
extension Data: UserDefaultsStorable {}
extension URL: UserDefaultsStorable {}

extension Array: RawRepresentable where Element: Codable {
    public init?(rawValue: String) {
        guard let data = rawValue.data(using: .utf8),
              let result = try? JSONDecoder().decode([Element].self, from: data)
        else {
            return nil
        }
        self = result
    }

    public var rawValue: String {
        guard let data = try? JSONEncoder().encode(self),
              let result = String(data: data, encoding: .utf8)
        else {
            return "[]"
        }
        return result
    }
}

public extension UserDefaults {
    // MARK: - Normal Types

    func value<K: UserDefaultPreferenceKey>(
        for keyPath: KeyPath<UserDefaultPreferenceKeys, K>
    ) -> K.Value where K.Value: UserDefaultsStorable {
        let key = UserDefaultPreferenceKeys()[keyPath: keyPath]
        return (value(forKey: key.key) as? K.Value) ?? key.defaultValue
    }

    func set<K: UserDefaultPreferenceKey>(
        _ value: K.Value,
        for keyPath: KeyPath<UserDefaultPreferenceKeys, K>
    ) where K.Value: UserDefaultsStorable {
        let key = UserDefaultPreferenceKeys()[keyPath: keyPath]
        set(value, forKey: key.key)
    }

    func setupDefaultValue<K: UserDefaultPreferenceKey>(
        for keyPath: KeyPath<UserDefaultPreferenceKeys, K>
    ) where K.Value: UserDefaultsStorable {
        let key = UserDefaultPreferenceKeys()[keyPath: keyPath]
        if value(forKey: key.key) == nil {
            set(key.defaultValue, forKey: key.key)
        }
    }
    
    func setupDefaultValue<K: UserDefaultPreferenceKey>(
        for keyPath: KeyPath<UserDefaultPreferenceKeys, K>,
        defaultValue: K.Value
    ) where K.Value: UserDefaultsStorable {
        let key = UserDefaultPreferenceKeys()[keyPath: keyPath]
        if value(forKey: key.key) == nil {
            set(defaultValue, forKey: key.key)
        }
    }

    // MARK: - Raw Representable

    func value<K: UserDefaultPreferenceKey>(
        for keyPath: KeyPath<UserDefaultPreferenceKeys, K>
    ) -> K.Value where K.Value: RawRepresentable, K.Value.RawValue == String {
        let key = UserDefaultPreferenceKeys()[keyPath: keyPath]
        guard let rawValue = value(forKey: key.key) as? String else {
            return key.defaultValue
        }
        return K.Value(rawValue: rawValue) ?? key.defaultValue
    }

    func value<K: UserDefaultPreferenceKey>(
        for keyPath: KeyPath<UserDefaultPreferenceKeys, K>
    ) -> K.Value where K.Value: RawRepresentable, K.Value.RawValue == Int {
        let key = UserDefaultPreferenceKeys()[keyPath: keyPath]
        guard let rawValue = value(forKey: key.key) as? Int else {
            return key.defaultValue
        }
        return K.Value(rawValue: rawValue) ?? key.defaultValue
    }

    func set<K: UserDefaultPreferenceKey>(
        _ value: K.Value,
        for keyPath: KeyPath<UserDefaultPreferenceKeys, K>
    ) where K.Value: RawRepresentable, K.Value.RawValue == String {
        let key = UserDefaultPreferenceKeys()[keyPath: keyPath]
        set(value.rawValue, forKey: key.key)
    }

    func set<K: UserDefaultPreferenceKey>(
        _ value: K.Value,
        for keyPath: KeyPath<UserDefaultPreferenceKeys, K>
    ) where K.Value: RawRepresentable, K.Value.RawValue == Int {
        let key = UserDefaultPreferenceKeys()[keyPath: keyPath]
        set(value.rawValue, forKey: key.key)
    }

    func setupDefaultValue<K: UserDefaultPreferenceKey>(
        for keyPath: KeyPath<UserDefaultPreferenceKeys, K>,
        defaultValue: K.Value? = nil
    ) where K.Value: RawRepresentable, K.Value.RawValue == String {
        let key = UserDefaultPreferenceKeys()[keyPath: keyPath]
        if value(forKey: key.key) == nil {
            set(defaultValue?.rawValue ?? key.defaultValue.rawValue, forKey: key.key)
        }
    }

    func setupDefaultValue<K: UserDefaultPreferenceKey>(
        for keyPath: KeyPath<UserDefaultPreferenceKeys, K>,
        defaultValue: K.Value? = nil
    ) where K.Value: RawRepresentable, K.Value.RawValue == Int {
        let key = UserDefaultPreferenceKeys()[keyPath: keyPath]
        if value(forKey: key.key) == nil {
            set(defaultValue?.rawValue ?? key.defaultValue.rawValue, forKey: key.key)
        }
    }
}
