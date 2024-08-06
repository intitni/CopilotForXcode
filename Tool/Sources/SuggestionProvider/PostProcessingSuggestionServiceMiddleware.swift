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
            Self.removeRedundantClosingParenthesis(&suggestion, lines: request.lines)
            if !Self.checkIfSuggestionHasNoEffect(suggestion, request: request) { return nil }
            Self.injectReplacingLines(&suggestion, request: request)
            return suggestion
        }
    }

    static func removeTrailingWhitespacesAndNewlines(_ suggestion: inout CodeSuggestion) {
        suggestion.text = suggestion.text.removedTrailingWhitespacesAndNewlines()
    }
    
    static func injectReplacingLines(
        _ suggestion: inout CodeSuggestion,
        request: SuggestionRequest
    ) {
        guard !request.lines.isEmpty else { return }
        let range = suggestion.range
        let lowerBound = max(0, range.start.line)
        let upperBound = max(lowerBound, min(request.lines.count - 1, range.end.line))
        suggestion.replacingLines = Array(request.lines[lowerBound...upperBound])
    }

    /// Remove the parenthesis in the last line of the suggestion if
    /// - It contains only closing parenthesis
    /// - It's identical to the next line below the range of the suggestion
    static func removeRedundantClosingParenthesis(
        _ suggestion: inout CodeSuggestion,
        lines: [String]
    ) {
        let nextLineIndex = suggestion.range.end.line + 1
        guard nextLineIndex < lines.endIndex, nextLineIndex >= 0 else { return }
        let nextLine = lines[nextLineIndex].dropLast(1)
        let lineBreakIndex = suggestion.text.lastIndex(where: { $0.isNewline })
        let lastLineIndex = if let index = lineBreakIndex {
            suggestion.text.index(after: index)
        } else {
            suggestion.text.startIndex
        }
        guard lastLineIndex < suggestion.text.endIndex else { return }
        let lastSuggestionLine = suggestion.text[lastLineIndex...]
        guard lastSuggestionLine == nextLine else { return }

        let closingParenthesis: [Character] = [")", "]", "}", ">"]
        let validCharacters = Set(closingParenthesis + [" ", ","])

        let trimmedLastSuggestionLine = nextLine.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedLastSuggestionLine.isEmpty else { return }

        if trimmedLastSuggestionLine == "```"
            || trimmedLastSuggestionLine == "\"\"\""
            || trimmedLastSuggestionLine.allSatisfy({ validCharacters.contains($0) })
        {
            if let lastIndex = lineBreakIndex {
                suggestion.text = String(suggestion.text[..<lastIndex])
            } else {
                suggestion.text = ""
            }
            suggestion.middlewareComments.append("Removed redundant closing parenthesis.")
        }
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

