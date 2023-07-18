import ASTParser
import ChatContextCollector
import Foundation
import OpenAIService
import Preferences
import SuggestionModel
import XcodeInspector

public final class ActiveDocumentChatContextCollector: ChatContextCollector {
    public init() {}

    public func generateContext(
        history: [ChatMessage],
        scopes: Set<String>,
        content: String
    ) -> ChatContext? {
        guard scopes.contains("file") else { return nil }
        let info = getEditorInformation()

        return .init(
            systemPrompt: extractSystemPrompt(info),
            functions: []
        )
    }
    
    func extractSystemPrompt(_ info: EditorInformation) -> String {
        let relativePath = info.documentURL.path
            .replacingOccurrences(of: info.projectURL.path, with: "")
        let selectionRange = info.editorContent?.selections.first ?? .outOfScope
        let lineAnnotations = info.editorContent?.lineAnnotations ?? []
        
        var result = """
        Active Document Context:###
        Document Relative Path: \(relativePath)
        Language: \(info.language.rawValue)
        Selection Range [line, character]: \
        [\(selectionRange.start.line), \(selectionRange.start.character)] - \
        [\(selectionRange.end.line), \(selectionRange.end.character)]
        ###
        """
        
        if !lineAnnotations.isEmpty {
            result += """
            Line Annotations:
            \(lineAnnotations.map { "  - \($0)" }.joined(separator: "\n"))
            """
        }
        
        return result
    }
}


