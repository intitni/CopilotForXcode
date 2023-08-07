import ASTParser
import ChatContextCollector
import Foundation
import OpenAIService
import Preferences
import SuggestionModel
import XcodeInspector

public final class ActiveDocumentChatContextCollector: ChatContextCollector {
    public init() {}

    var activeDocumentContext: ActiveDocumentContext?

    public func generateContext(
        history: [ChatMessage],
        scopes: Set<String>,
        content: String
    ) -> ChatContext? {
        guard let info = getEditorInformation() else { return nil }
        let context = getActiveDocumentContext(info)
        activeDocumentContext = context

        guard scopes.contains("code") || scopes.contains("c") else {
            if scopes.contains("file") || scopes.contains("f") {
                var removedCode = context
                removedCode.focusedContext = nil
                return .init(
                    systemPrompt: extractSystemPrompt(removedCode),
                    functions: []
                )
            }
            return nil
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

        print(extractSystemPrompt(context))

        return .init(
            systemPrompt: extractSystemPrompt(context),
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

        You can use the following context to answer user's questions about the editing document or code. The context shows only a part of the code in the editing document, and will change during the conversation, so it may not match our conversation.

        User Editing Document Context: ###
        """
        let end = "###"
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
            Focused Code (start from line \(
                focusedContext.codeRange.start
                    .line
            )):
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
                end,
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
                end,
            ]
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
        }
    }

    func convertAnnotationToText(_ annotation: EditorInformation.LineAnnotation) -> String {
        return "- Line \(annotation.line), \(annotation.type): \(annotation.message)"
    }
}

struct ActiveDocumentContext {
    var filePath: String
    var relativePath: String
    var language: CodeLanguage
    var fileContent: String
    var lines: [String]
    var selectedCode: String
    var selectionRange: CursorRange
    var lineAnnotations: [EditorInformation.LineAnnotation]
    var imports: [String]

    struct FocusedContext {
        var context: [String]
        var contextRange: CursorRange
        var codeRange: CursorRange
        var code: String
        var lineAnnotations: [EditorInformation.LineAnnotation]
        var otherLineAnnotations: [EditorInformation.LineAnnotation]
    }

    var focusedContext: FocusedContext?

    mutating func moveToFocusedCode() {
        moveToCodeContainingRange(selectionRange)
    }

    mutating func moveToCodeAroundLine(_ line: Int) {
        moveToCodeContainingRange(.init(
            start: .init(line: line, character: 0),
            end: .init(line: line, character: 0)
        ))
    }

    mutating func expandFocusedRangeToContextRange() {
        guard let focusedContext else { return }
        moveToCodeContainingRange(focusedContext.contextRange)
    }

    mutating func moveToCodeContainingRange(_ range: CursorRange) {
        let finder: FocusedCodeFinder = {
            switch language {
            case .builtIn(.swift):
                return SwiftFocusedCodeFinder()
            default:
                return UnknownLanguageFocusedCodeFinder()
            }
        }()

        let codeContext = finder.findFocusedCode(
            containingRange: range,
            activeDocumentContext: self
        )

        imports = codeContext.imports

        let startLine = codeContext.focusedRange.start.line
        let endLine = codeContext.focusedRange.end.line
        var matchedAnnotations = [EditorInformation.LineAnnotation]()
        var otherAnnotations = [EditorInformation.LineAnnotation]()
        for annotation in lineAnnotations {
            if annotation.line >= startLine, annotation.line <= endLine {
                matchedAnnotations.append(annotation)
            } else {
                otherAnnotations.append(annotation)
            }
        }

        focusedContext = .init(
            context: codeContext.scopeSignatures,
            contextRange: codeContext.contextRange,
            codeRange: codeContext.focusedRange,
            code: codeContext.focusedCode,
            lineAnnotations: matchedAnnotations,
            otherLineAnnotations: otherAnnotations
        )
    }

    mutating func update(_ info: EditorInformation) {
        /// Whenever the file content, relative path, or selection range changes,
        /// we should reset the context.
        let changed: Bool = {
            if info.relativePath != relativePath { return true }
            if info.editorContent?.content != fileContent { return true }
            if let range = info.editorContent?.selections.first,
               range != selectionRange { return true }
            return false
        }()

        filePath = info.documentURL.path
        relativePath = info.relativePath
        language = info.language
        fileContent = info.editorContent?.content ?? ""
        lines = info.editorContent?.lines ?? []
        selectedCode = info.selectedContent
        selectionRange = info.editorContent?.selections.first ?? .zero
        lineAnnotations = info.editorContent?.lineAnnotations ?? []
        imports = []
        
        if changed {
            moveToFocusedCode()
        }
    }
}

