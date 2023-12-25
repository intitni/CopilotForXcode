import Foundation

public enum BuiltInSuggestionFeatureProvider: Int, CaseIterable, Codable {
    case gitHubCopilot
    case codeium
}

public enum SuggestionFeatureProvider: Codable, RawRepresentable, Hashable {
    case builtIn(BuiltInSuggestionFeatureProvider)
    case `extension`(name: String, bundleIdentifier: String)

    public init?(rawValue: String) {
        guard let data = rawValue.data(using: .utf8),
              let value = try? JSONDecoder().decode(Self.self, from: data)
        else { return nil }

        self = value
    }

    public var rawValue: String {
        if let data = try? JSONEncoder().encode(self) {
            return String(data: data, encoding: .utf8) ?? ""
        }
        return ""
    }
}

