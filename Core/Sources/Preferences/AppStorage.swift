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
    ) where K.Value == Value, Value == R?, R : RawRepresentable, R.RawValue == String {
        let key = UserDefaultPreferenceKeys()[keyPath: keyPath]
        self.init(key.key, store: .shared)
    }

    init<K: UserDefaultPreferenceKey, R>(
        _ keyPath: KeyPath<UserDefaultPreferenceKeys, K>
    ) where K.Value == Value, Value == R?, R : RawRepresentable, R.RawValue == Int {
        let key = UserDefaultPreferenceKeys()[keyPath: keyPath]
        self.init(key.key, store: .shared)
    }
}

#endif
