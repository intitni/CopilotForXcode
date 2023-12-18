import Foundation

public enum BuiltInSuggestionFeatureProvider: Int, CaseIterable, Codable {
    case gitHubCopilot
    case codeium
}

public enum SuggestionFeatureProvider: Codable {
    case builtIn(BuiltInSuggestionFeatureProvider)
    case extended(name: String, bundleIdentifier: String)
}

