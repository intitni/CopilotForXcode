import Foundation
import SuggestionModel
import XcodeInspector

struct EditorInformation {
    let editorContent: SourceEditor.Content?
    let selectedContent: String
    let selectedLines: [String]
    let documentURL: URL
    let projectURL: URL
    let relativePath: String
    let language: CodeLanguage

    func code(in range: CursorRange) -> String {
        return EditorInformation.code(in: selectedLines, inside: range).code
    }

    static func lines(in code: [String], containing range: CursorRange) -> [String] {
        let startIndex = min(max(0, range.start.line), code.endIndex - 1)
        let endIndex = min(max(startIndex, range.end.line), code.endIndex - 1)
        let selectedLines = code[startIndex...endIndex]
        return Array(selectedLines)
    }

    static func code(in code: [String], inside range: CursorRange) -> (code: String, lines: [String]) {
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

func getEditorInformation() -> EditorInformation {
    let editorContent = XcodeInspector.shared.focusedEditor?.content
    let documentURL = XcodeInspector.shared.activeDocumentURL
    let projectURL = XcodeInspector.shared.activeProjectURL
    let language = languageIdentifierFromFileURL(documentURL)
    let relativePath = documentURL.path
        .replacingOccurrences(of: projectURL.path, with: "")

    if let editorContent, let range = editorContent.selections.first {
        let (selectedContent, selectedLines) = EditorInformation.code(
            in: editorContent.lines,
            inside: range
        )
        return .init(
            editorContent: editorContent,
            selectedContent: selectedContent,
            selectedLines: selectedLines,
            documentURL: documentURL,
            projectURL: projectURL,
            relativePath: relativePath,
            language: language
        )
    }

    return .init(
        editorContent: editorContent,
        selectedContent: "",
        selectedLines: [],
        documentURL: documentURL,
        projectURL: projectURL,
        relativePath: relativePath,
        language: language
    )
}

