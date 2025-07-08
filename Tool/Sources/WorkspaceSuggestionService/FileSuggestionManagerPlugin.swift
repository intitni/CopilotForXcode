import Foundation
import IdentifiedCollections
import Perception
import SuggestionBasic
import Workspace

public final class FileSuggestionManagerPlugin: FilespacePlugin {
    static var suggestionProviders: [ObjectIdentifier: (FileSuggestionManager)
        -> FilespaceSuggestionProvider] = [:]

    public let suggestionManager = {
        let suggestionManager = FileSuggestionManager()
        for provider in suggestionProviders.values {
            let provider = provider(suggestionManager)
            suggestionManager.suggestionProviders.append(provider)
            provider.delegate = suggestionManager
        }
        return suggestionManager
    }()

    public static func registerSuggestionProvider<Provider: FilespaceSuggestionProvider>(
        _ provider: @escaping (FileSuggestionManager) -> Provider
    ) {
        let id = ObjectIdentifier(Provider.self)
        suggestionProviders[id] = provider
    }
}

public extension Filespace {
    var suggestionManager: FileSuggestionManager? {
        plugin(for: FileSuggestionManagerPlugin.self)?.suggestionManager
    }
}
