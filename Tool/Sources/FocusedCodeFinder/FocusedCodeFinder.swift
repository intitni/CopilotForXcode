import Foundation
import SuggestionModel

public struct CodeContext: Equatable {
    public typealias ScopeContext = ActiveDocumentContext.FocusedContext.Context
    
    public enum Scope: Equatable {
        case file
        case top
        case scope(signature: [ScopeContext])
    }

    public var scopeContexts: [ScopeContext] {
        switch scope {
        case .file:
            return []
        case .top:
            return []
        case let .scope(contexts):
            return contexts
        }
    }

    public var scope: Scope
    public var contextRange: CursorRange
    public var focusedRange: CursorRange
    public var focusedCode: String
    public var imports: [String]

    public static var empty: CodeContext {
        .init(scope: .file, contextRange: .zero, focusedRange: .zero, focusedCode: "", imports: [])
    }

    public init(
        scope: Scope,
        contextRange: CursorRange,
        focusedRange: CursorRange,
        focusedCode: String,
        imports: [String]
    ) {
        self.scope = scope
        self.contextRange = contextRange
        self.focusedRange = focusedRange
        self.focusedCode = focusedCode
        self.imports = imports
    }
}

public protocol FocusedCodeFinder {
    func findFocusedCode(
        containingRange: CursorRange,
        activeDocumentContext: ActiveDocumentContext
    ) -> CodeContext
}

public struct UnknownLanguageFocusedCodeFinder: FocusedCodeFinder {
    let proposedSearchRange: Int

    public init(proposedSearchRange: Int) {
        self.proposedSearchRange = proposedSearchRange
    }

    public func findFocusedCode(
        containingRange: CursorRange,
        activeDocumentContext: ActiveDocumentContext
    ) -> CodeContext {
        guard !activeDocumentContext.lines.isEmpty else { return .empty }

        // when user is not selecting any code.
        if containingRange.start == containingRange.end {
            // search up and down for up to `proposedSearchRange * 2 + 1` lines.
            let lines = activeDocumentContext.lines
            let proposedLineCount = proposedSearchRange * 2 + 1
            let startLineIndex = max(containingRange.start.line - proposedSearchRange, 0)
            let endLineIndex = min(
                max(
                    startLineIndex,
                    min(startLineIndex + proposedLineCount - 1, lines.count - 1)
                ),
                lines.count - 1
            )

            guard endLineIndex >= startLineIndex else { return .empty }
            let focusedLines = lines[startLineIndex...endLineIndex]

            let contextStartLine = max(startLineIndex - 5, 0)
            let contextEndLine = min(endLineIndex + 5, lines.count - 1)

            return .init(
                scope: .top,
                contextRange: .init(
                    start: .init(line: contextStartLine, character: 0),
                    end: .init(line: contextEndLine, character: lines[contextEndLine].count)
                ),
                focusedRange: .init(
                    start: .init(line: startLineIndex, character: 0),
                    end: .init(line: endLineIndex, character: lines[endLineIndex].count)
                ),
                focusedCode: focusedLines.joined(),
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
                end: .init(
                    line: contextEndLine,
                    character: activeDocumentContext.lines[contextEndLine].count
                )
            ),
            focusedRange: containingRange,
            focusedCode: focusedLines.joined(),
            imports: []
        )
    }
}

