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
    public var includes: [String]

    public static var empty: CodeContext {
        .init(scope: .file, contextRange: .zero, focusedRange: .zero, focusedCode: "", imports: [])
    }

    public init(
        scope: Scope,
        contextRange: CursorRange,
        focusedRange: CursorRange,
        focusedCode: String,
        imports: [String],
        includes: [String]
    ) {
        self.scope = scope
        self.contextRange = contextRange
        self.focusedRange = focusedRange
        self.focusedCode = focusedCode
        self.imports = imports
        self.includes = includes
    }
}

public struct FocusedCodeFinder {
    public init() {}
    
    public struct Document {
        var documentURL: URL
        var content: String
        var lines: [String]
        
        public init(documentURL: URL, content: String, lines: [String]) {
            self.documentURL = documentURL
            self.content = content
            self.lines = lines
        }
    }
    
    public func findFocusedCode(
        in document: Document,
        containingRange: CursorRange,
        language: CodeLanguage
    ) -> CodeContext {
        let finder: FocusedCodeFinderType = {
            switch language {
            case .builtIn(.swift):
                return SwiftFocusedCodeFinder()
            default:
                return UnknownLanguageFocusedCodeFinder(proposedSearchRange: 5)
            }
        }()

        return finder.findFocusedCode(in: document, containingRange: containingRange)
    }
}

public protocol FocusedCodeFinderType {
    typealias Document = FocusedCodeFinder.Document
    
    func findFocusedCode(
        in document: Document,
        containingRange: CursorRange
    ) -> CodeContext
}

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
        let endLine = min(containingRange.end.line, document.lines.count - 1)

        if endLine < startLine { return .empty }

        let focusedLines = document.lines[startLine...endLine]
        let contextStartLine = max(startLine - 3, 0)
        let contextEndLine = min(endLine + 3, document.lines.count - 1)

        return CodeContext(
            scope: .top,
            contextRange: .init(
                start: .init(line: contextStartLine, character: 0),
                end: .init(
                    line: contextEndLine,
                    character: document.lines[contextEndLine].count
                )
            ),
            focusedRange: containingRange,
            focusedCode: focusedLines.joined(),
            imports: []
        )
    }
}

