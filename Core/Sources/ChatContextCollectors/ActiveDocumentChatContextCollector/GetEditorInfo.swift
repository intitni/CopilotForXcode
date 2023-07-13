import Foundation
import SuggestionModel
import XcodeInspector

struct Information {
    let editorContent: SourceEditor.Content?
    let selectedContent: String
    let documentURL: URL
    let projectURL: URL
    let language: CodeLanguage
}

func getEditorInformation() -> Information {
    let editorContent = XcodeInspector.shared.focusedEditor?.content
    let documentURL = XcodeInspector.shared.activeDocumentURL
    let projectURL = XcodeInspector.shared.activeProjectURL
    let language = languageIdentifierFromFileURL(documentURL)

    if let editorContent, let range = editorContent.selections.first {
        let startIndex = min(
            max(0, range.start.line),
            editorContent.lines.endIndex - 1
        )
        let endIndex = min(
            max(startIndex, range.end.line),
            editorContent.lines.endIndex - 1
        )
        let selectedContent = editorContent.lines[startIndex...endIndex]
        return .init(
            editorContent: editorContent,
            selectedContent: selectedContent.joined(),
            documentURL: documentURL,
            projectURL: projectURL,
            language: language
        )
    }

    return .init(
        editorContent: editorContent,
        selectedContent: "",
        documentURL: documentURL,
        projectURL: projectURL,
        language: language
    )
}

