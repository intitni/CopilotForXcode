import ASTParser
import ChatContextCollector
import Dependencies
import FocusedCodeFinder
import Foundation
import GitIgnoreCheck
import OpenAIService
import Preferences
import SuggestionModel
import XcodeInspector

public final class ActiveDocumentChatContextCollector: ChatContextCollector {
    public init() {}

    public var activeDocumentContext: ActiveDocumentContext?

    @Dependency(\.gitIgnoredChecker) var gitIgnoredChecker

    public func generateContext(
        history: [ChatMessage],
        scopes: Set<ChatContext.Scope>,
        content: String,
        configuration: ChatGPTConfiguration
    ) async -> ChatContext {
        guard let info = getEditorInformation() else { return .empty }
        let context = getActiveDocumentContext(info)
        activeDocumentContext = context

        let isSensitive = await gitIgnoredChecker.checkIfGitIgnored(fileURL: info.documentURL)

        guard scopes.contains(.code)
        else {
            if scopes.contains(.file) {
                var removedCode = context
                removedCode.focusedContext = nil
                return .init(
                    systemPrompt: extractSystemPrompt(removedCode, isSensitive: isSensitive),
                    retrievedContent: [],
                    functions: []
                )
            }
            return .empty
        }

        var functions = [any ChatGPTFunction]()

        if !isSensitive {
            functions.append(GetCodeCodeAroundLineFunction(contextCollector: self))
        }

        return .init(
            systemPrompt: extractSystemPrompt(context, isSensitive: isSensitive),
            retrievedContent: [],
            functions: functions
        )
    }

    func getActiveDocumentContext(_ info: EditorInformation) -> ActiveDocumentContext {
        var activeDocumentContext = activeDocumentContext ?? .init(
            documentURL: .init(fileURLWithPath: "/"),
            relativePath: "",
            language: .builtIn(.swift),
            fileContent: "",
            lines: [],
            selectedCode: "",
            selectionRange: .outOfScope,
            lineAnnotations: [],
            imports: [],
            includes: []
        )

        activeDocumentContext.update(info)
        return activeDocumentContext
    }

    func extractSystemPrompt(_ context: ActiveDocumentContext, isSensitive: Bool) -> String {
        let start = """
        ## File and Code Scope

        You can use the following context to answer my questions about the editing document.\
        The context shows only a part of the code in the editing document.

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
            let codeContext = focusedContext.context.isEmpty || isSensitive
                ? ""
                : """
                Focused Context:
                ```
                \(focusedContext.context.map(\.signature).joined(separator: "\n"))
                ```
                """

            let codeRange = "Focused Range [line, character]: \(focusedContext.codeRange)"

            let code = context.selectionRange.isEmpty && isSensitive
                ? """
                The file is in gitignore, you can't read the file.
                Ask the user to select the code in the editor to get help. Also tell them the file is in gitignore.
                """
                : """
                Focused Code (from line \(
                    focusedContext.codeRange.start.line + 1
                ) to line \(focusedContext.codeRange.end.line + 1)):
                ```\(context.language.rawValue)
                \(focusedContext.code)
                ```
                """

            let fileAnnotations = focusedContext.otherLineAnnotations.isEmpty || isSensitive
                ? ""
                : """
                Out-of-scope Annotations:\"""
                (They are not inside the focused code. You can get the code at the line for details)
                \(
                    focusedContext.otherLineAnnotations
                        .map(convertAnnotationToText)
                        .joined(separator: "\n")
                )
                \"""
                """

            let codeAnnotations = focusedContext.lineAnnotations.isEmpty || isSensitive
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
            let lineAnnotations = context.lineAnnotations.isEmpty || isSensitive
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

