import Foundation
import Logger
import SuggestionBasic

public protocol SuggestionServiceMiddleware {
    typealias Next = (SuggestionRequest) async throws -> [CodeSuggestion]

    func getSuggestion(
        _ request: SuggestionRequest,
        configuration: SuggestionServiceConfiguration,
        next: Next
    ) async throws -> [CodeSuggestion]
}

public enum SuggestionServiceMiddlewareContainer {
    static var builtInMiddlewares: [SuggestionServiceMiddleware] = [
        DisabledLanguageSuggestionServiceMiddleware(),
        PostProcessingSuggestionServiceMiddleware()
    ]
    
    static var leadingMiddlewares: [SuggestionServiceMiddleware] = []

    static var trailingMiddlewares: [SuggestionServiceMiddleware] = []

    public static var middlewares: [SuggestionServiceMiddleware] {
        leadingMiddlewares + builtInMiddlewares + trailingMiddlewares
    }

    public static func addMiddleware(_ middleware: SuggestionServiceMiddleware) {
        trailingMiddlewares.append(middleware)
    }
    
    public static func addMiddlewares(_ middlewares: [SuggestionServiceMiddleware]) {
        trailingMiddlewares.append(contentsOf: middlewares)
    }

    public static func addLeadingMiddleware(_ middleware: SuggestionServiceMiddleware) {
        leadingMiddlewares.append(middleware)
    }
    
    public static func addLeadingMiddlewares(_ middlewares: [SuggestionServiceMiddleware]) {
        leadingMiddlewares.append(contentsOf: middlewares)
    }
}

public struct DisabledLanguageSuggestionServiceMiddleware: SuggestionServiceMiddleware {
    public init() {}
    
    struct DisabledLanguageError: Error, LocalizedError {
        let language: String
        var errorDescription: String? {
            "Suggestion service is disabled for \(language)."
        }
    }

    public func getSuggestion(
        _ request: SuggestionRequest,
        configuration: SuggestionServiceConfiguration,
        next: Next
    ) async throws -> [CodeSuggestion] {
        let language = languageIdentifierFromFileURL(request.fileURL)
        if UserDefaults.shared.value(for: \.suggestionFeatureDisabledLanguageList)
            .contains(where: { $0 == language.rawValue })
        {
            throw DisabledLanguageError(language: language.rawValue)
        }

        return try await next(request)
    }
}

public struct DebugSuggestionServiceMiddleware: SuggestionServiceMiddleware {
    public init() {}

    public func getSuggestion(
        _ request: SuggestionRequest,
        configuration: SuggestionServiceConfiguration,
        next: Next
    ) async throws -> [CodeSuggestion] {
        Logger.service.info("""
        Get suggestion for \(request.fileURL) at \(request.cursorPosition)
        """)
        do {
            let suggestions = try await next(request)
            Logger.service.info("""
            Receive \(suggestions.count) suggestions for \(request.fileURL) \
            at \(request.cursorPosition)
            """)
            return suggestions
        } catch {
            Logger.service.info("""
            Error: \(error.localizedDescription)
            """)
            throw error
        }
    }
}

