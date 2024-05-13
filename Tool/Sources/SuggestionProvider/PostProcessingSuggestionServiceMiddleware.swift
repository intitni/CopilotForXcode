import Foundation
import SuggestionModel

public struct PostProcessingSuggestionServiceMiddleware: SuggestionServiceMiddleware {
    public init() {}

    public func getSuggestion(
        _ request: SuggestionRequest,
        configuration: SuggestionServiceConfiguration,
        next: Next
    ) async throws -> [CodeSuggestion] {
        let suggestions = try await next(request)

        return suggestions.compactMap {
            var suggestion = $0
            Self.removeTrailingWhitespacesAndNewlines(&suggestion)
            if suggestion.text.isEmpty { return nil }
            return suggestion
        }
    }

    static func removeTrailingWhitespacesAndNewlines(_ suggestion: inout CodeSuggestion) {
        var text = suggestion.text[...]
        while let last = text.last, last.isNewline || last.isWhitespace {
            text = text.dropLast(1)
        }
        suggestion.text = String(text)
    }

    static func checkIfSuggestionHasNoEffect(
        _ suggestion: CodeSuggestion,
        request: SuggestionRequest
    ) -> Bool {
        suggestion.text.isEmpty
    }
}

