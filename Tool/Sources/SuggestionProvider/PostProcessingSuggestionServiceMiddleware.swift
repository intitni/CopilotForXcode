import Foundation
import SuggestionBasic

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
            if suggestion.text.allSatisfy({ $0.isWhitespace || $0.isNewline }) { return nil }
            Self.removeTrailingWhitespacesAndNewlines(&suggestion)
            if !Self.checkIfSuggestionHasNoEffect(suggestion, request: request) { return nil }
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
        // We only check suggestions that are on a single line.
        if suggestion.range.isOneLine {
            let line = suggestion.range.start.line
            if line >= 0, line < request.lines.count {
                let replacingText = request.lines[line]

                let start = suggestion.range.start.character
                let end = suggestion.range.end.character
                if let endIndex = replacingText.utf16.index(
                    replacingText.startIndex,
                    offsetBy: end,
                    limitedBy: replacingText.endIndex
                ),
                    let startIndex = replacingText.utf16.index(
                        replacingText.startIndex,
                        offsetBy: start,
                        limitedBy: endIndex
                    ),
                    startIndex < endIndex
                {
                    let replacingRange = startIndex..<endIndex
                    // Build up the replaced text.
                    let replacedText = replacingText.replacingCharacters(
                        in: replacingRange,
                        with: suggestion.text
                    )

                    // If it's identical to the original text, ignore the suggestion.
                    if replacedText == replacingText { return false }
                }
            }
        }

        return true
    }
}

