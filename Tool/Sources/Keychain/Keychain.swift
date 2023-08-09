import Configs
import Foundation
import Security

public struct Keychain {
    let service = keychainService
    let accessGroup = keychainAccessGroup

    public enum Error: Swift.Error {
        case failedToDeleteFromKeyChain
        case failedToUpdateOrSetItem
    }

    public init() {}
    
    func query(_ key: String) -> [String: Any] {
        [
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
