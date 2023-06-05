import Foundation
import SuggestionModel
import XcodeInspector

struct CustomCommandTemplateProcessor {
    func process(_ text: String) -> String {
        let info = getEditorInformation()
        if let editorContent = info.editorContent {
            let updatedText = text.replacingOccurrences(of: "{{selected_code}}", with: """
            ```\(info.language.rawValue)
            \(editorContent.selectedContent.trimmingCharacters(in: ["\n"]))
            ```
            """)
            return updatedText
        } else {
            let updatedText = text.replacingOccurrences(of: "{{selected_code}}", with: "")
            return updatedText
        }
    }

    struct EditorInformation {
        let editorContent: SourceEditor.Content?
        let language: CodeLanguage
    }

    func getEditorInformation() -> EditorInformation {
        let editorContent = XcodeInspector.shared.focusedEditor?.content
        let documentURL = XcodeInspector.shared.activeDocumentURL
        let language = languageIdentifierFromFileURL(documentURL)

        return .init(
            editorContent: editorContent,
            language: language
        )
    }
}

