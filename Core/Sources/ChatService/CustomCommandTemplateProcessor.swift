import AppKit
import Foundation
import SuggestionModel
import XcodeInspector

public struct CustomCommandTemplateProcessor {
    public init() {}
    
    public func process(_ text: String) -> String {
        let info = getEditorInformation()
        let editorContent = info.editorContent
        let updatedText = text
            .replacingOccurrences(of: "{{selected_code}}", with: """
            \(editorContent?.selectedContent.trimmingCharacters(in: .whitespacesAndNewlines) ?? "")
            """)
            .replacingOccurrences(
                of: "{{active_editor_language}}",
                with: info.language.rawValue
            )
            .replacingOccurrences(
                of: "{{active_editor_file_url}}",
                with: info.documentURL?.path ?? ""
            )
            .replacingOccurrences(
                of: "{{active_editor_file_name}}",
                with: info.documentURL?.lastPathComponent ?? ""
            )
            .replacingOccurrences(
                of: "{{clipboard}}",
                with: NSPasteboard.general.string(forType: .string) ?? ""
            )
        return updatedText
    }

    struct EditorInformation {
        let editorContent: SourceEditor.Content?
        let language: CodeLanguage
        let documentURL: URL?
    }

    func getEditorInformation() -> EditorInformation {
        let editorContent = XcodeInspector.shared.focusedEditor?.getContent()
        let documentURL = XcodeInspector.shared.activeDocumentURL
        let language = documentURL.map(languageIdentifierFromFileURL) ?? .plaintext

        return .init(
            editorContent: editorContent,
            language: language,
            documentURL: documentURL
        )
    }
}

