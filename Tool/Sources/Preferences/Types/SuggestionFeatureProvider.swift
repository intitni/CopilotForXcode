import Foundation

public enum BuiltInSuggestionFeatureProvider: Int, CaseIterable, Codable {
    case gitHubCopilot
    case codeium
}

public enum SuggestionFeatureProvider: RawRepresentable, Hashable {
    case builtIn(BuiltInSuggestionFeatureProvider)
    case `extension`(name: String, bundleIdentifier: String)

    enum Storage: Codable {
        case builtIn(BuiltInSuggestionFeatureProvider)
        case `extension`(name: String, bundleIdentifier: String)
    }

    public init?(rawValue: String) {
        guard let data = rawValue.data(using: .utf8),
              let value = try? JSONDecoder().decode(Storage.self, from: data)
        else { return nil }

        switch value {
        case let .builtIn(provider):
            self = .builtIn(provider)
        case let .extension(name, bundleIdentifier):
            self = .extension(name: name, bundleIdentifier: bundleIdentifier)
        }
    }

    public var rawValue: String {
        let storage: Storage = switch self {
        case let .builtIn(provider): .builtIn(provider)
        case let .extension(name, bundleIdentifier):
            .extension(name: name, bundleIdentifier: bundleIdentifier)
        }
        if let data = try? JSONEncoder().encode(storage) {
            return String(data: data, encoding: .utf8) ?? ""
        }
        return ""
    }
}

