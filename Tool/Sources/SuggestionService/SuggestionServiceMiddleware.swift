import Foundation
import SuggestionModel
import Logger

public protocol SuggestionServiceMiddleware {
    typealias Next = (SuggestionRequest) async throws -> [CodeSuggestion]
    
    func getSuggestion(_ request: SuggestionRequest, next: Next) async throws -> [CodeSuggestion]
}

struct DisabledLanguageSuggestionServiceMiddleware: SuggestionServiceMiddleware {
    func getSuggestion(_ request: SuggestionRequest, next: Next) async throws -> [CodeSuggestion] {
        let language = languageIdentifierFromFileURL(request.fileURL)
        if UserDefaults.shared.value(for: \.suggestionFeatureDisabledLanguageList)
            .contains(where: { $0 == language.rawValue })
        {
            #if DEBUG
            Logger.service.info("Suggestion service is disabled for \(language).")
            #endif
            return []
        }
        
        return try await next(request)
    }
}

public struct DebugSuggestionServiceMiddleware: SuggestionServiceMiddleware {
    public init() {}
    
    public func getSuggestion(_ request: SuggestionRequest, next: Next) async throws -> [CodeSuggestion] {
        Logger.service.debug("""
        Get suggestion for \(request.fileURL) at \(request.cursorPosition)
        """)
        let suggestions = try await next(request)
        Logger.service.debug("""
        Receive \(suggestions.count) suggestions for \(request.fileURL) at \(request.cursorPosition)
        """)
        
        return suggestions
    }
}
