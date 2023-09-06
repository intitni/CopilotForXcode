import Foundation
import SuggestionModel

public struct ActiveDocumentContext {
    public var filePath: String
    public var relativePath: String
    public var language: CodeLanguage
    public var fileContent: String
    public var lines: [String]
    public var selectedCode: String
    public var selectionRange: CursorRange
    public var lineAnnotations: [EditorInformation.LineAnnotation]
    public var imports: [String]

    public struct FocusedContext {
        public var context: [String]
        public var contextRange: CursorRange
        public var codeRange: CursorRange
        public var code: String
        public var lineAnnotations: [EditorInformation.LineAnnotation]
        public var otherLineAnnotations: [EditorInformation.LineAnnotation]

        public init(
            context: [String],
            contextRange: CursorRange,
            codeRange: CursorRange,
            code: String,
            lineAnnotations: [EditorInformation.LineAnnotation],
            otherLineAnnotations: [EditorInformation.LineAnnotation]
        ) {
            self.context = context
            self.contextRange = contextRange
            self.codeRange = codeRange
            self.code = code
            self.lineAnnotations = lineAnnotations
            self.otherLineAnnotations = otherLineAnnotations
        }
    }

    public var focusedContext: FocusedContext?

    public init(
        filePath: String,
        relativePath: String,
        language: CodeLanguage,
        fileContent: String,
        lines: [String],
        selectedCode: String,
        selectionRange: CursorRange,
        lineAnnotations: [EditorInformation.LineAnnotation],
        imports: [String],
        focusedContext: FocusedContext? = nil
    ) {
        self.filePath = filePath
        self.relativePath = relativePath
        self.language = language
        self.fileContent = fileContent
        self.lines = lines
        self.selectedCode = selectedCode
        self.selectionRange = selectionRange
        self.lineAnnotations = lineAnnotations
        self.imports = imports
        self.focusedContext = focusedContext
    }

    public mutating func moveToFocusedCode() {
        moveToCodeContainingRange(selectionRange)
    }

    public mutating func moveToCodeAroundLine(_ line: Int) {
        moveToCodeContainingRange(.init(
            start: .init(line: line, character: 0),
            end: .init(line: line, character: 0)
        ))
    }

    public mutating func expandFocusedRangeToContextRange() {
        guard let focusedContext else { return }
        moveToCodeContainingRange(focusedContext.contextRange)
    }

    public mutating func moveToCodeContainingRange(_ range: CursorRange) {
        let finder: FocusedCodeFinder = {
            switch language {
            case .builtIn(.swift):
                return SwiftFocusedCodeFinder()
            default:
                return UnknownLanguageFocusedCodeFinder(proposedSearchRange: 5)
            }
        }()

        let codeContext = finder.findFocusedCode(
            containingRange: range,
            activeDocumentContext: self
        )

        imports = codeContext.imports

        let startLine = codeContext.focusedRange.start.line
        let endLine = codeContext.focusedRange.end.line
        var matchedAnnotations = [EditorInformation.LineAnnotation]()
        var otherAnnotations = [EditorInformation.LineAnnotation]()
        for annotation in lineAnnotations {
            if annotation.line >= startLine, annotation.line <= endLine {
                matchedAnnotations.append(annotation)
            } else {
                otherAnnotations.append(annotation)
            }
        }

        focusedContext = .init(
            context: codeContext.scopeSignatures,
            contextRange: codeContext.contextRange,
            codeRange: codeContext.focusedRange,
            code: codeContext.focusedCode,
            lineAnnotations: matchedAnnotations,
            otherLineAnnotations: otherAnnotations
        )
    }

    public mutating func update(_ info: EditorInformation) {
        /// Whenever the file content, relative path, or selection range changes,
        /// we should reset the context.
        let changed: Bool = {
            if info.relativePath != relativePath { return true }
            if info.editorContent?.content != fileContent { return true }
            if let range = info.editorContent?.selections.first,
               range != selectionRange { return true }
            return false
        }()

        filePath = info.documentURL.path
        relativePath = info.relativePath
        language = info.language
        fileContent = info.editorContent?.content ?? ""
        lines = info.editorContent?.lines ?? []
        selectedCode = info.selectedContent
        selectionRange = info.editorContent?.selections.first ?? .zero
        lineAnnotations = info.editorContent?.lineAnnotations ?? []
        imports = []

        if changed {
            moveToFocusedCode()
        }
    }
}

