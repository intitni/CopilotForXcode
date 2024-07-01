import Foundation
import SuggestionBasic

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
    public var smallestContextRange: CursorRange
    public var focusedRange: CursorRange
    public var focusedCode: String
    public var imports: [String]
    public var includes: [String]

    public static var empty: CodeContext {
        .init(
            scope: .file,
            contextRange: .zero,
            smallestContextRange: .zero,
            focusedRange: .zero,
            focusedCode: "",
            imports: [],
            includes: []
        )
    }

    public init(
        scope: Scope,
        contextRange: CursorRange,
        smallestContextRange: CursorRange,
        focusedRange: CursorRange,
        focusedCode: String,
        imports: [String],
        includes: [String]
    ) {
        self.scope = scope
        self.contextRange = contextRange
        self.smallestContextRange = smallestContextRange
        self.focusedRange = focusedRange
        self.focusedCode = focusedCode
        self.imports = imports
        self.includes = includes
    }
}

public struct FocusedCodeFinder {
    public let maxFocusedCodeLineCount: Int

    public init(maxFocusedCodeLineCount: Int) {
        self.maxFocusedCodeLineCount = maxFocusedCodeLineCount
    }

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
                return SwiftFocusedCodeFinder(maxFocusedCodeLineCount: maxFocusedCodeLineCount)
            case .builtIn(.objc), .builtIn(.objcpp), .builtIn(.c):
                #warning(
                    "TODO: Implement C++ focused code finder, use it for C and metal shading language"
                )
                return ObjectiveCFocusedCodeFinder(maxFocusedCodeLineCount: maxFocusedCodeLineCount)
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

