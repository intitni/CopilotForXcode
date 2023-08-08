import Foundation
import OpenAIService
import Preferences
import SuggestionModel
import XcodeInspector
import ChatContextCollector

public struct LegacyActiveDocumentChatContextCollector: ChatContextCollector {
    public init() {}

    public func generateContext(
        history: [ChatMessage],
        scopes: Set<String>,
        content: String
    ) -> ChatContext? {
        guard let content = getEditorInformation() else { return nil }
        let relativePath = content.relativePath
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
                    .value(for: \.maxFocusedCodeLineCount)
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

            if UserDefaults.shared.value(for: \.useCodeScopeByDefaultInChatContext) {
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


