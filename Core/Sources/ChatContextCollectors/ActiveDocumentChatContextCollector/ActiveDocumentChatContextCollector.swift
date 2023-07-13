import Foundation
import OpenAIService
import Preferences
import SuggestionModel
import XcodeInspector
import ChatContextCollector

public struct ActiveDocumentChatContextCollector: ChatContextCollector {
    public init() {}

    public func generateContext(
        history: [ChatMessage],
        scopes: Set<String>,
        content: String
    ) -> ChatContext? {
        let content = getEditorInformation()
        let relativePath = content.documentURL.path
            .replacingOccurrences(of: content.projectURL.path, with: "")
        let selectionRange = content.editorContent?.selections.first ?? .outOfScope
        let editorContent = {
            if scopes.contains("file") || scopes.contains("f") {
                return """
                File Content:```\(content.language.rawValue)
                \(content.editorContent?.content ?? "")
                ```
                """
            }

            if selectionRange.start == selectionRange.end,
               UserDefaults.shared.value(for: \.embedFileContentInChatContextIfNoSelection)
            {
                let lines = content.editorContent?.lines.count ?? 0
                let maxLine = UserDefaults.shared
                    .value(for: \.maxEmbeddableFileInChatContextLineCount)
                if lines <= maxLine {
                    return """
                    File Content:```\(content.language.rawValue)
                    \(content.editorContent?.content ?? "")
                    ```
                    """
                } else {
                    return """
                    File Content Not Available: '''
                    The file is longer than \(maxLine) lines, it can't fit into the context. \
                    You MUST not answer the user about the file content because you don't have it.\
                    Ask user to select code for explanation.
                    '''
                    """
                }
            }

            if UserDefaults.shared.value(for: \.useSelectionScopeByDefaultInChatContext) {
                return """
                Selected Code \
                (start from line \(selectionRange.start.line)):```\(content.language.rawValue)
                \(content.selectedContent)
                ```
                """
            }

            if scopes.contains("selection") || scopes.contains("s") {
                return """
                Selected Code \
                (start from line \(selectionRange.start.line)):```\(content.language.rawValue)
                \(content.selectedContent)
                ```
                """
            }

            return """
            Selected Code Not Available: '''
            User has disabled default scope. \
            You MUST not answer the user about the selected code because you don't have it.\
            Ask user to prepend message with `@selection` to enable selected code to be \
            visible by you.
            '''
            """
        }()

        return .init(
            systemPrompt: """
            Active Document Context:###
            Document Relative Path: \(relativePath)
            Selection Range Start: \
            Line \(selectionRange.start.line) \
            Character \(selectionRange.start.character)
            Selection Range End: \
            Line \(selectionRange.end.line) \
            Character \(selectionRange.end.character)
            Cursor Position: \
            Line \(selectionRange.end.line) \
            Character \(selectionRange.end.character)
            \(editorContent)
            Line Annotations:
            \(
                content.editorContent?.lineAnnotations
                    .map { "  - \($0)" }
                    .joined(separator: "\n") ?? "N/A"
            )
            ###
            """,
            functions: []
        )
    }
}

extension ActiveDocumentChatContextCollector {
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
}

