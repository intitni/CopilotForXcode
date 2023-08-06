import Foundation
import SuggestionModel

struct CodeContext: Equatable {
    enum Scope: Equatable {
        case file
        case top
        case scope(signature: String)
    }

    var scope: Scope
    var contextRange: CursorRange
    var focusedRange: CursorRange
    var focusedCode: String
    var imports: [String]

    static var empty: CodeContext {
        .init(scope: .file, contextRange: .zero, focusedRange: .zero, focusedCode: "", imports: [])
    }
}

protocol FocusedCodeFinder {
    func findFocusedCode(
        containingRange: CursorRange,
        activeDocumentContext: ActiveDocumentContext
    ) -> CodeContext
}

struct UnknownLanguageFocusedCodeFinder: FocusedCodeFinder {
    func findFocusedCode(
        containingRange: CursorRange,
        activeDocumentContext: ActiveDocumentContext
    ) -> CodeContext {
        guard !activeDocumentContext.lines.isEmpty else { return .empty }

        // when user is not selecting any code.
        if containingRange.start == containingRange.end {
            // search up and down for up to 7 lines.
            let lines = activeDocumentContext.lines
            var startLineIndex = max(containingRange.start.line - 3, 0)
            let endLineIndex = min(containingRange.start.line + 3, lines.count - 1)
            if endLineIndex - startLineIndex <= 6, startLineIndex > 0 {
                startLineIndex = max(startLineIndex - (6 - (endLineIndex - startLineIndex)), 0)
            }
            let focusedLines = lines[startLineIndex...endLineIndex]

            let contextStartLine = max(startLineIndex - 3, 0)
            let contextEndLine = min(endLineIndex + 3, lines.count - 1)

            return .init(
                scope: .top,
                contextRange: .init(
                    start: .init(line: contextStartLine, character: 0),
                    end: .init(line: contextEndLine, character: 0)
                ),
                focusedRange: containingRange,
                focusedCode: focusedLines.joined(separator: "\n"),
                imports: []
            )
        }

        let startLine = max(containingRange.start.line, 0)
        let endLine = min(containingRange.end.line, activeDocumentContext.lines.count - 1)

        if endLine < startLine { return .empty }

        let focusedLines = activeDocumentContext.lines[startLine...endLine]
        let contextStartLine = max(startLine - 3, 0)
        let contextEndLine = min(endLine + 3, activeDocumentContext.lines.count - 1)

        return CodeContext(
            scope: .top,
            contextRange: .init(
                start: .init(line: contextStartLine, character: 0),
                end: .init(line: contextEndLine, character: 0)
            ),
            focusedRange: containingRange,
            focusedCode: focusedLines.joined(separator: "\n"),
            imports: []
        )
    }
}

