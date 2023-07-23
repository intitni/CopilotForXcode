import Foundation
import SuggestionModel
import XcodeInspector

func getEditorInformation() -> EditorInformation? {
    guard !XcodeInspector.shared.xcodes.isEmpty else { return nil }
    
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

