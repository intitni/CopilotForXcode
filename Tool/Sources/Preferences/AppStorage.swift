import Foundation

#if canImport(SwiftUI)

import SwiftUI

public extension AppStorage {
    init<K: UserDefaultPreferenceKey>(
        _ keyPath: KeyPath<UserDefaultPreferenceKeys, K>
    ) where K.Value == Value, Value == Bool {
        let key = UserDefaultPreferenceKeys()[keyPath: keyPath]
        self.init(wrappedValue: key.defaultValue, key.key, store: .shared)
    }

    init<K: UserDefaultPreferenceKey>(
        _ keyPath: KeyPath<UserDefaultPreferenceKeys, K>
    ) where K.Value == Value, Value == String {
        let key = UserDefaultPreferenceKeys()[keyPath: keyPath]
        self.init(wrappedValue: key.defaultValue, key.key, store: .shared)
    }

    init<K: UserDefaultPreferenceKey>(
        _ keyPath: KeyPath<UserDefaultPreferenceKeys, K>
    ) where K.Value == Value, Value == Double {
        let key = UserDefaultPreferenceKeys()[keyPath: keyPath]
        self.init(wrappedValue: key.defaultValue, key.key, store: .shared)
    }

    init<K: UserDefaultPreferenceKey>(
        _ keyPath: KeyPath<UserDefaultPreferenceKeys, K>
    ) where K.Value == Value, Value == Int {
        let key = UserDefaultPreferenceKeys()[keyPath: keyPath]
        self.init(wrappedValue: key.defaultValue, key.key, store: .shared)
    }

    init<K: UserDefaultPreferenceKey>(
        _ keyPath: KeyPath<UserDefaultPreferenceKeys, K>
    ) where K.Value == Value, Value == URL {
        let key = UserDefaultPreferenceKeys()[keyPath: keyPath]
        self.init(wrappedValue: key.defaultValue, key.key, store: .shared)
    }

    init<K: UserDefaultPreferenceKey>(
        _ keyPath: KeyPath<UserDefaultPreferenceKeys, K>
    ) where K.Value == Value, Value == Data {
        let key = UserDefaultPreferenceKeys()[keyPath: keyPath]
        self.init(wrappedValue: key.defaultValue, key.key, store: .shared)
    }

    init<K: UserDefaultPreferenceKey>(
        _ keyPath: KeyPath<UserDefaultPreferenceKeys, K>
    ) where K.Value == Value, Value: RawRepresentable, Value.RawValue == Int {
        let key = UserDefaultPreferenceKeys()[keyPath: keyPath]
        self.init(wrappedValue: key.defaultValue, key.key, store: .shared)
    }

    init<K: UserDefaultPreferenceKey>(
        _ keyPath: KeyPath<UserDefaultPreferenceKeys, K>
    ) where K.Value == Value, Value: RawRepresentable, Value.RawValue == String {
        let key = UserDefaultPreferenceKeys()[keyPath: keyPath]
        self.init(wrappedValue: key.defaultValue, key.key, store: .shared)
    }
}

public extension AppStorage where Value: ExpressibleByNilLiteral {
    init<K: UserDefaultPreferenceKey>(
        _ keyPath: KeyPath<UserDefaultPreferenceKeys, K>
    ) where K.Value == Value, Value == Bool? {
        let key = UserDefaultPreferenceKeys()[keyPath: keyPath]
        self.init(key.key, store: .shared)
    }

    init<K: UserDefaultPreferenceKey>(
        _ keyPath: KeyPath<UserDefaultPreferenceKeys, K>
    ) where K.Value == Value, Value == String? {
        let key = UserDefaultPreferenceKeys()[keyPath: keyPath]
        self.init(key.key, store: .shared)
    }

    init<K: UserDefaultPreferenceKey>(
        _ keyPath: KeyPath<UserDefaultPreferenceKeys, K>
    ) where K.Value == Value, Value == Double? {
        let key = UserDefaultPreferenceKeys()[keyPath: keyPath]
        self.init(key.key, store: .shared)
    }

    init<K: UserDefaultPreferenceKey>(
        _ keyPath: KeyPath<UserDefaultPreferenceKeys, K>
    ) where K.Value == Value, Value == Int? {
        let key = UserDefaultPreferenceKeys()[keyPath: keyPath]
        self.init(key.key, store: .shared)
    }

    init<K: UserDefaultPreferenceKey>(
        _ keyPath: KeyPath<UserDefaultPreferenceKeys, K>
    ) where K.Value == Value, Value == URL? {
        let key = UserDefaultPreferenceKeys()[keyPath: keyPath]
        self.init(key.key, store: .shared)
    }

    init<K: UserDefaultPreferenceKey>(
        _ keyPath: KeyPath<UserDefaultPreferenceKeys, K>
    ) where K.Value == Value, Value == Data? {
        let key = UserDefaultPreferenceKeys()[keyPath: keyPath]
        self.init(key.key, store: .shared)
    }
}

public extension AppStorage {
    init<K: UserDefaultPreferenceKey, R>(
        _ keyPath: KeyPath<UserDefaultPreferenceKeys, K>
    ) where K.Value == Value, Value == R?, R: RawRepresentable, R.RawValue == String {
        let key = UserDefaultPreferenceKeys()[keyPath: keyPath]
        self.init(key.key, store: .shared)
    }

    init<K: UserDefaultPreferenceKey, R>(
        _ keyPath: KeyPath<UserDefaultPreferenceKeys, K>
    ) where K.Value == Value, Value == R?, R: RawRepresentable, R.RawValue == Int {
        let key = UserDefaultPreferenceKeys()[keyPath: keyPath]
        self.init(key.key, store: .shared)
    }
}

// MARK: - Deprecated Key Accessor

public extension AppStorage {
    @available(*, deprecated, message: "This preference key is deprecated.")
    init(
        _ keyPath: KeyPath<UserDefaultPreferenceKeys, DeprecatedPreferenceKey<Value>>
    ) where Value == Bool {
        let key = UserDefaultPreferenceKeys()[keyPath: keyPath]
        self.init(wrappedValue: key.defaultValue, key.key, store: .shared)
    }

    @available(*, deprecated, message: "This preference key is deprecated.")
    init(
        _ keyPath: KeyPath<UserDefaultPreferenceKeys, DeprecatedPreferenceKey<Value>>
    ) where Value == String {
        let key = UserDefaultPreferenceKeys()[keyPath: keyPath]
        self.init(wrappedValue: key.defaultValue, key.key, store: .shared)
    }

    @available(*, deprecated, message: "This preference key is deprecated.")
    init(
        _ keyPath: KeyPath<UserDefaultPreferenceKeys, DeprecatedPreferenceKey<Value>>
    ) where Value == Double {
        let key = UserDefaultPreferenceKeys()[keyPath: keyPath]
        self.init(wrappedValue: key.defaultValue, key.key, store: .shared)
    }

    @available(*, deprecated, message: "This preference key is deprecated.")
    init(
        _ keyPath: KeyPath<UserDefaultPreferenceKeys, DeprecatedPreferenceKey<Value>>
    ) where Value == Int {
        let key = UserDefaultPreferenceKeys()[keyPath: keyPath]
        self.init(wrappedValue: key.defaultValue, key.key, store: .shared)
    }

    @available(*, deprecated, message: "This preference key is deprecated.")
    init(
        _ keyPath: KeyPath<UserDefaultPreferenceKeys, DeprecatedPreferenceKey<Value>>
    ) where Value == URL {
        let key = UserDefaultPreferenceKeys()[keyPath: keyPath]
        self.init(wrappedValue: key.defaultValue, key.key, store: .shared)
    }

    @available(*, deprecated, message: "This preference key is deprecated.")
    init(
        _ keyPath: KeyPath<UserDefaultPreferenceKeys, DeprecatedPreferenceKey<Value>>
    ) where Value == Data {
        let key = UserDefaultPreferenceKeys()[keyPath: keyPath]
        self.init(wrappedValue: key.defaultValue, key.key, store: .shared)
    }

    @available(*, deprecated, message: "This preference key is deprecated.")
    init(
        _ keyPath: KeyPath<UserDefaultPreferenceKeys, DeprecatedPreferenceKey<Value>>
    ) where Value: RawRepresentable, Value.RawValue == Int {
        let key = UserDefaultPreferenceKeys()[keyPath: keyPath]
        self.init(wrappedValue: key.defaultValue, key.key, store: .shared)
    }

    @available(*, deprecated, message: "This preference key is deprecated.")
    init(
        _ keyPath: KeyPath<UserDefaultPreferenceKeys, DeprecatedPreferenceKey<Value>>
    ) where Value: RawRepresentable, Value.RawValue == String {
        let key = UserDefaultPreferenceKeys()[keyPath: keyPath]
        self.init(wrappedValue: key.defaultValue, key.key, store: .shared)
    }
}

public extension AppStorage where Value: ExpressibleByNilLiteral {
    @available(*, deprecated, message: "This preference key is deprecated.")
    init(
        _ keyPath: KeyPath<UserDefaultPreferenceKeys, DeprecatedPreferenceKey<Value>>
    ) where Value == Bool? {
        let key = UserDefaultPreferenceKeys()[keyPath: keyPath]
        self.init(key.key, store: .shared)
    }

    @available(*, deprecated, message: "This preference key is deprecated.")
    init(
        _ keyPath: KeyPath<UserDefaultPreferenceKeys, DeprecatedPreferenceKey<Value>>
    ) where Value == String? {
        let key = UserDefaultPreferenceKeys()[keyPath: keyPath]
        self.init(key.key, store: .shared)
    }

    @available(*, deprecated, message: "This preference key is deprecated.")
    init(
        _ keyPath: KeyPath<UserDefaultPreferenceKeys, DeprecatedPreferenceKey<Value>>
    ) where Value == Double? {
        let key = UserDefaultPreferenceKeys()[keyPath: keyPath]
        self.init(key.key, store: .shared)
    }

    @available(*, deprecated, message: "This preference key is deprecated.")
    init(
        _ keyPath: KeyPath<UserDefaultPreferenceKeys, DeprecatedPreferenceKey<Value>>
    ) where Value == Int? {
        let key = UserDefaultPreferenceKeys()[keyPath: keyPath]
        self.init(key.key, store: .shared)
    }

    @available(*, deprecated, message: "This preference key is deprecated.")
    init(
        _ keyPath: KeyPath<UserDefaultPreferenceKeys, DeprecatedPreferenceKey<Value>>
    ) where Value == URL? {
        let key = UserDefaultPreferenceKeys()[keyPath: keyPath]
        self.init(key.key, store: .shared)
    }

    @available(*, deprecated, message: "This preference key is deprecated.")
    init(
        _ keyPath: KeyPath<UserDefaultPreferenceKeys, DeprecatedPreferenceKey<Value>>
    ) where Value == Data? {
        let key = UserDefaultPreferenceKeys()[keyPath: keyPath]
        self.init(key.key, store: .shared)
    }
}

public extension AppStorage {
    @available(*, deprecated, message: "This preference key is deprecated.")
    init<R>(
        _ keyPath: KeyPath<UserDefaultPreferenceKeys, DeprecatedPreferenceKey<Value>>
    ) where Value == R?, R: RawRepresentable, R.RawValue == String {
        let key = UserDefaultPreferenceKeys()[keyPath: keyPath]
        self.init(key.key, store: .shared)
    }

    @available(*, deprecated, message: "This preference key is deprecated.")
    init<R>(
        _ keyPath: KeyPath<UserDefaultPreferenceKeys, DeprecatedPreferenceKey<Value>>
    ) where Value == R?, R: RawRepresentable, R.RawValue == Int {
        let key = UserDefaultPreferenceKeys()[keyPath: keyPath]
        self.init(key.key, store: .shared)
    }
}

#endif

