import Foundation
import Preferences
import SuggestionBasic

/// Used when the language is not supported by the app
/// or that the code is too long to be returned by a focused code finder.
public struct UnknownLanguageFocusedCodeFinder: FocusedCodeFinderType {
    let proposedSearchRange: Int

    public init(proposedSearchRange: Int) {
        self.proposedSearchRange = proposedSearchRange
    }

    public func findFocusedCode(
        in document: Document,
        containingRange: CursorRange
    ) -> CodeContext {
        guard !document.lines.isEmpty else { return .empty }

        // when user is not selecting any code.
        if containingRange.start == containingRange.end {
            // search up and down for up to `proposedSearchRange * 2 + 1` lines.
            let lines = document.lines
            let proposedLineCount = proposedSearchRange * 2 + 1
            let startLineIndex = max(containingRange.start.line - proposedSearchRange, 0)
            let endLineIndex = max(
                startLineIndex,
                min(startLineIndex + proposedLineCount - 1, lines.count - 1)
            )

            if lines.endIndex <= endLineIndex { return .empty }
            
            let focusedLines = lines[startLineIndex...endLineIndex]

            let contextStartLine = max(startLineIndex - 5, 0)
            let contextEndLine = min(endLineIndex + 5, lines.count - 1)
            
            let contextRange = CursorRange(
                start: .init(line: contextStartLine, character: 0),
                end: .init(line: contextEndLine, character: lines[contextEndLine].count)
            )

            return .init(
                scope: .top,
                contextRange: contextRange,
                smallestContextRange: contextRange,
                focusedRange: .init(
                    start: .init(line: startLineIndex, character: 0),
                    end: .init(line: endLineIndex, character: lines[endLineIndex].count)
                ),
                focusedCode: focusedLines.joined(),
                imports: [],
                includes: []
            )
        }

        let startLine = max(containingRange.start.line, 0)
        let endLine = min(containingRange.end.line, document.lines.count - 1)

        if endLine < startLine { return .empty }

        let focusedLines = document.lines[startLine...endLine]
        let contextStartLine = max(startLine - 3, 0)
        let contextEndLine = min(endLine + 3, document.lines.count - 1)
        
        let contextRange = CursorRange(
            start: .init(line: contextStartLine, character: 0),
            end: .init(
                line: contextEndLine,
                character: document.lines[contextEndLine].count
            )
        )

        return CodeContext(
            scope: .top,
            contextRange: contextRange,
            smallestContextRange: contextRange,
            focusedRange: containingRange,
            focusedCode: focusedLines.joined(),
            imports: [],
            includes: []
        )
    }
}

