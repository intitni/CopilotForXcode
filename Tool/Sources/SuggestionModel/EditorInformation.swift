import Foundation

public struct EditorInformation {
    public struct SourceEditorContent {
        /// The content of the source editor.
        public var content: String
        /// The content of the source editor in lines.
        public var lines: [String]
        /// The selection ranges of the source editor.
        public var selections: [CursorRange]
        /// The cursor position of the source editor.
        public var cursorPosition: CursorPosition
        /// Line annotations of the source editor.
        public var lineAnnotations: [String]

        public var selectedContent: String {
            if let range = selections.first {
                let startIndex = min(
                    max(0, range.start.line),
                    lines.endIndex - 1
                )
                let endIndex = min(
                    max(startIndex, range.end.line),
                    lines.endIndex - 1
                )
                let selectedContent = lines[startIndex...endIndex]
                return selectedContent.joined()
            }
            return ""
        }

        public init(
            content: String,
            lines: [String],
            selections: [CursorRange],
            cursorPosition: CursorPosition,
            lineAnnotations: [String]
        ) {
            self.content = content
            self.lines = lines
            self.selections = selections
            self.cursorPosition = cursorPosition
            self.lineAnnotations = lineAnnotations
        }
    }

    public let editorContent: SourceEditorContent?
    public let selectedContent: String
    public let selectedLines: [String]
    public let documentURL: URL
    public let projectURL: URL
    public let relativePath: String
    public let language: CodeLanguage

    public init(
        editorContent: SourceEditorContent?,
        selectedContent: String,
        selectedLines: [String],
        documentURL: URL,
        projectURL: URL,
        relativePath: String,
        language: CodeLanguage
    ) {
        self.editorContent = editorContent
        self.selectedContent = selectedContent
        self.selectedLines = selectedLines
        self.documentURL = documentURL
        self.projectURL = projectURL
        self.relativePath = relativePath
        self.language = language
    }

    public func code(in range: CursorRange) -> String {
        return EditorInformation.code(in: selectedLines, inside: range).code
    }

    public static func lines(in code: [String], containing range: CursorRange) -> [String] {
        let startIndex = min(max(0, range.start.line), code.endIndex - 1)
        let endIndex = min(max(startIndex, range.end.line), code.endIndex - 1)
        let selectedLines = code[startIndex...endIndex]
        return Array(selectedLines)
    }

    public static func code(
        in code: [String],
        inside range: CursorRange
    ) -> (code: String, lines: [String]) {
        let rangeLines = lines(in: code, containing: range)
        var selectedContent = rangeLines
        if !selectedContent.isEmpty {
            selectedContent[0] = String(selectedContent[0].dropFirst(range.start.character))
            selectedContent[selectedContent.endIndex - 1] = String(
                selectedContent[selectedContent.endIndex - 1].dropLast(
                    selectedContent[selectedContent.endIndex - 1].count - range.end.character
                )
            )
        }
        return (selectedContent.joined(), rangeLines)
    }
}

