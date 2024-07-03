import Foundation
import SuggestionBasic

public struct ActiveDocumentContext {
    public var documentURL: URL
    public var relativePath: String
    public var language: CodeLanguage
    public var fileContent: String
    public var lines: [String]
    public var selectedCode: String
    public var selectionRange: CursorRange
    public var lineAnnotations: [EditorInformation.LineAnnotation]
    public var imports: [String]
    public var includes: [String]

    public struct FocusedContext {
        public struct Context: Equatable {
            public var signature: String
            public var name: String
            public var range: CursorRange

            public init(signature: String, name: String, range: CursorRange) {
                self.signature = signature
                self.name = name
                self.range = range
            }
        }

        public var context: [Context]
        public var contextRange: CursorRange
        public var smallestContextRange: CursorRange
        public var codeRange: CursorRange
        public var code: String
        public var lineAnnotations: [EditorInformation.LineAnnotation]
        public var otherLineAnnotations: [EditorInformation.LineAnnotation]

        public init(
            context: [Context],
            contextRange: CursorRange,
            smallestContextRange: CursorRange,
            codeRange: CursorRange,
            code: String,
            lineAnnotations: [EditorInformation.LineAnnotation],
            otherLineAnnotations: [EditorInformation.LineAnnotation]
        ) {
            self.context = context
            self.contextRange = contextRange
            self.smallestContextRange = smallestContextRange
            self.codeRange = codeRange
            self.code = code
            self.lineAnnotations = lineAnnotations
            self.otherLineAnnotations = otherLineAnnotations
        }
    }

    public var focusedContext: FocusedContext?

    public init(
        documentURL: URL,
        relativePath: String,
        language: CodeLanguage,
        fileContent: String,
        lines: [String],
        selectedCode: String,
        selectionRange: CursorRange,
        lineAnnotations: [EditorInformation.LineAnnotation],
        imports: [String],
        includes: [String],
        focusedContext: FocusedContext? = nil
    ) {
        self.documentURL = documentURL
        self.relativePath = relativePath
        self.language = language
        self.fileContent = fileContent
        self.lines = lines
        self.selectedCode = selectedCode
        self.selectionRange = selectionRange
        self.lineAnnotations = lineAnnotations
        self.imports = imports
        self.includes = includes
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
        let finder = FocusedCodeFinder(
            maxFocusedCodeLineCount: UserDefaults.shared.value(for: \.maxFocusedCodeLineCount)
        )

        let codeContext = finder.findFocusedCode(
            in: .init(documentURL: documentURL, content: fileContent, lines: lines),
            containingRange: range,
            language: language
        )

        imports = codeContext.imports
        includes = codeContext.includes

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
            context: codeContext.scopeContexts,
            contextRange: codeContext.contextRange,
            smallestContextRange: codeContext.smallestContextRange,
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

        documentURL = info.documentURL
        relativePath = info.relativePath
        language = info.language
        fileContent = info.editorContent?.content ?? ""
        lines = info.editorContent?.lines ?? []
        selectedCode = info.selectedContent
        selectionRange = info.editorContent?.selections.first ?? .zero
        lineAnnotations = info.editorContent?.lineAnnotations ?? []
        imports = []
        includes = []

        if changed {
            moveToFocusedCode()
        }
    }
}

