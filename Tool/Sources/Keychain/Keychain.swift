import Configs
import Foundation
import Preferences
import Security

public protocol KeychainType {
    func getAll() throws -> [String: String]
    func update(_ value: String, key: String) throws
    func get(_ key: String) throws -> String?
    func remove(_ key: String) throws
}

public final class FakeKeyChain: KeychainType {
    var values: [String: String] = [:]

    public init() {}

    public func getAll() throws -> [String: String] {
        values
    }

    public func update(_ value: String, key: String) throws {
        values[key] = value
    }

    public func get(_ key: String) throws -> String? {
        values[key]
    }

    public func remove(_ key: String) throws {
        values[key] = nil
    }
}

public final class UserDefaultsBaseAPIKeychain: KeychainType {
    let defaults = UserDefaults.shared
    let scope: String
    var key: String {
        "UserDefaultsBaseAPIKeychain-\(scope)"
    }
    
    init(scope: String) {
        self.scope = scope
    }
    
    public func getAll() throws -> [String : String] {
        defaults.dictionary(forKey: key) as? [String: String] ?? [:]
    }
    
    public func update(_ value: String, key: String) throws {
        var dict = try getAll()
        dict[key] = value
        defaults.set(dict, forKey: self.key)
    }
    
    public func get(_ key: String) throws -> String? {
        try getAll()[key]
    }
    
    public func remove(_ key: String) throws {
        var dict = try getAll()
        dict[key] = nil
        defaults.set(dict, forKey: self.key)
    }
}

public struct Keychain: KeychainType {
    let service = keychainService
    let accessGroup = keychainAccessGroup
    let scope: String

    public static var apiKey: KeychainType {
        if UserDefaults.shared.value(for: \.useUserDefaultsBaseAPIKeychain) {
            return UserDefaultsBaseAPIKeychain(scope: "apiKey")
        }
        return Keychain(scope: "apiKey")
    }

    public enum Error: Swift.Error {
        case failedToDeleteFromKeyChain
        case failedToUpdateOrSetItem
    }

    public init(scope: String = "") {
        self.scope = scope
    }

    func query(_ key: String) -> [String: Any] {
        let key = scopeKey(key)
        return [
            kSecClass as String: kSecClassGenericPassword as String,
            kSecAttrService as String: service,
            kSecAttrAccessGroup as String: accessGroup,
            kSecAttrAccount as String: key,
            kSecUseDataProtectionKeychain as String: true,
        ]
    }

    func set(_ value: String, key: String) throws {
        let query = query(key).merging([
            kSecValueData as String: value.data(using: .utf8) ?? Data(),
        ], uniquingKeysWith: { _, b in b })

        let result = SecItemAdd(query as CFDictionary, nil)

        switch result {
        case noErr:
            return
        default:
            throw Error.failedToUpdateOrSetItem
        }
    }

    func scopeKey(_ key: String) -> String {
        if scope.isEmpty {
            return key
        }
        return "\(scope)::\(key)"
    }

    func escapeScope(_ key: String) -> String? {
        if scope.isEmpty {
            return key
        }
        if !key.hasPrefix("\(scope)::") { return nil }
        return key.replacingOccurrences(of: "\(scope)::", with: "")
    }

    public func getAll() throws -> [String: String] {
        let query = [
            kSecClass as String: kSecClassGenericPassword as String,
            kSecAttrService as String: service,
            kSecAttrAccessGroup as String: accessGroup,
            kSecReturnAttributes as String: true,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll,
        ] as [String: Any]

        var result: AnyObject?
        if SecItemCopyMatching(query as CFDictionary, &result) == noErr {
            guard let items = result as? [[String: Any]] else {
                return [:]
            }

            var dict = [String: String]()
            for item in items {
                guard let key = item[kSecAttrAccount as String] as? String,
                      let escapedKey = escapeScope(key)
                else { continue }
                guard let valueData = item[kSecValueData as String] as? Data,
                      let value = String(data: valueData, encoding: .utf8)
                else { continue }
                dict[escapedKey] = value
            }
            return dict
        }

        return [:]
    }

    public func update(_ value: String, key: String) throws {
        let query = query(key).merging([
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecReturnData as String: true,
        ], uniquingKeysWith: { _, b in b })

        let attributes: [String: Any] =
            [kSecValueData as String: value.data(using: .utf8) ?? Data()]

        let result = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)

        switch result {
        case noErr:
            return
        case errSecItemNotFound:
            try set(value, key: key)
        default:
            throw Error.failedToUpdateOrSetItem
        }
    }

    public func get(_ key: String) throws -> String? {
        let query = query(key).merging([
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecReturnData as String: true,
            kSecReturnAttributes as String: true,
        ], uniquingKeysWith: { _, b in b })

        var item: CFTypeRef?
        if SecItemCopyMatching(query as CFDictionary, &item) == noErr {
            if let existingItem = item as? [String: Any],
               let passwordData = existingItem[kSecValueData as String] as? Data,
               let password = String(data: passwordData, encoding: .utf8)
            {
                return password
            }
            return nil
        } else {
            return nil
        }
    }

    public func remove(_ key: String) throws {
        if SecItemDelete(query(key) as CFDictionary) == noErr {
            return
        }
        throw Error.failedToDeleteFromKeyChain
    }
}

