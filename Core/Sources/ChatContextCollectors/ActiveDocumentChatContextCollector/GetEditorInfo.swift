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
}

func getEditorInformation() -> EditorInformation {
    let editorContent = XcodeInspector.shared.focusedEditor?.content
    let documentURL = XcodeInspector.shared.activeDocumentURL
    let projectURL = XcodeInspector.shared.activeProjectURL
    let language = languageIdentifierFromFileURL(documentURL)
    let relativePath = documentURL.path
        .replacingOccurrences(of: projectURL.path, with: "")

    if let editorContent, let range = editorContent.selections.first {
        let startIndex = min(
            max(0, range.start.line),
            editorContent.lines.endIndex - 1
        )
        let endIndex = min(
            max(startIndex, range.end.line),
            editorContent.lines.endIndex - 1
        )
        let selectedLines = editorContent.lines[startIndex...endIndex]
        var selectedContent = selectedLines
        if selectedContent.count > 0 {
            selectedContent[0] = String(selectedContent[0].dropFirst(range.start.character))
            selectedContent[selectedContent.endIndex - 1] = String(
                selectedContent[selectedContent.endIndex - 1].dropLast(
                    selectedContent[selectedContent.endIndex - 1].count - range.end.character
                )
            )
        }
        return .init(
            editorContent: editorContent,
            selectedContent: selectedContent.joined(),
            selectedLines: Array(selectedLines),
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

