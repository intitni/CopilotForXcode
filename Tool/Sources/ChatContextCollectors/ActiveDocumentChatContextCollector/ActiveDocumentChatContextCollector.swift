import ASTParser
import ChatContextCollector
import FocusedCodeFinder
import Foundation
import OpenAIService
import Preferences
import SuggestionModel
import XcodeInspector

public final class ActiveDocumentChatContextCollector: ChatContextCollector {
    public init() {}

    public var activeDocumentContext: ActiveDocumentContext?

    public func generateContext(
        history: [ChatMessage],
        scopes: Set<String>,
        content: String,
        configuration: ChatGPTConfiguration
    ) -> ChatContext {
        guard let info = getEditorInformation() else { return .empty }
        let context = getActiveDocumentContext(info)
        activeDocumentContext = context

        guard scopes.contains("code") || scopes.contains("c") else {
            if scopes.contains("file") || scopes.contains("f") {
                var removedCode = context
                removedCode.focusedContext = nil
                return .init(
                    systemPrompt: extractSystemPrompt(removedCode),
                    retrievedContent: [],
                    functions: []
                )
            }
            return .empty
        }

        var functions = [any ChatGPTFunction]()

        // When the bot is already focusing on a piece of code, it can expand the range.

        if context.focusedContext != nil {
            functions.append(ExpandFocusRangeFunction(contextCollector: self))
        }

        // When the bot is not focusing on any code, or the focusing area is not the user's
        // selection, it can move the focus back to the user's selection.

        if context.focusedContext == nil ||
            !(context.focusedContext?.codeRange.contains(context.selectionRange) ?? false)
        {
            functions.append(MoveToFocusedCodeFunction(contextCollector: self))
        }

        // When there is a line annotation not in the focused area, the bot can move the focus area
        // to the code covering the line of the annotation.

        if let focusedContext = context.focusedContext,
           !focusedContext.otherLineAnnotations.isEmpty
        {
            functions.append(MoveToCodeAroundLineFunction(contextCollector: self))
        }

        if context.focusedContext == nil, !context.lineAnnotations.isEmpty {
            functions.append(MoveToCodeAroundLineFunction(contextCollector: self))
        }

        return .init(
            systemPrompt: extractSystemPrompt(context),
            retrievedContent: [],
            functions: functions
        )
    }

    func getActiveDocumentContext(_ info: EditorInformation) -> ActiveDocumentContext {
        var activeDocumentContext = activeDocumentContext ?? .init(
            filePath: "",
            relativePath: "",
            language: .builtIn(.swift),
            fileContent: "",
            lines: [],
            selectedCode: "",
            selectionRange: .outOfScope,
            lineAnnotations: [],
            imports: []
        )

        activeDocumentContext.update(info)
        return activeDocumentContext
    }

    func extractSystemPrompt(_ context: ActiveDocumentContext) -> String {
        let start = """
        ## File and Code Scope

        You can use the following context to answer my questions about the editing document or code. The context shows only a part of the code in the editing document, and will change during the conversation, so it may not match our conversation.

        \(
            context.focusedContext == nil
                ? ""
                : "When you don't known what I am asking, I am probably referring to the code."
        )

        ### Editing Document Context
        """
        let relativePath = "Document Relative Path: \(context.relativePath)"
        let language = "Language: \(context.language.rawValue)"

        if let focusedContext = context.focusedContext {
            let codeContext = focusedContext.context.isEmpty
                ? ""
                : """
                Focused Context:
                ```
                \(focusedContext.context.joined(separator: "\n"))
                ```
                """

            let codeRange = "Focused Range [line, character]: \(focusedContext.codeRange)"

            let code = """
            Focused Code (start from line \(focusedContext.codeRange.start.line + 1)):
            ```\(context.language.rawValue)
            \(focusedContext.code)
            ```
            """

            let fileAnnotations = focusedContext.otherLineAnnotations.isEmpty
                ? ""
                : """
                Other Annotations:\"""
                (They are not inside the focused code. You don't known how to handle them until you get the code at the line)
                \(
                    focusedContext.otherLineAnnotations
                        .map(convertAnnotationToText)
                        .joined(separator: "\n")
                )
                \"""
                """

            let codeAnnotations = focusedContext.lineAnnotations.isEmpty
                ? ""
                : """
                Annotations Inside Focused Range:\"""
                \(
                    focusedContext.lineAnnotations
                        .map(convertAnnotationToText)
                        .joined(separator: "\n")
                )
                \"""
                """

            return [
                start,
                relativePath,
                language,
                codeContext,
                codeRange,
                code,
                codeAnnotations,
                fileAnnotations,
            ]
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
        } else {
            let selectionRange = "Selection Range [line, character]: \(context.selectionRange)"
            let lineAnnotations = context.lineAnnotations.isEmpty
                ? ""
                : """
                Line Annotations:\"""
                \(context.lineAnnotations.map(convertAnnotationToText).joined(separator: "\n"))
                \"""
                """

            return [
                start,
                relativePath,
                language,
                lineAnnotations,
                selectionRange,
            ]
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
        }
    }

    func convertAnnotationToText(_ annotation: EditorInformation.LineAnnotation) -> String {
        return "- Line \(annotation.line), \(annotation.type): \(annotation.message)"
    }
}

