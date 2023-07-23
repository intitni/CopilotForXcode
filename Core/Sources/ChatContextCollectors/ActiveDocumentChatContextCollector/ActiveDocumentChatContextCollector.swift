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

        return .init(
            systemPrompt: extractSystemPrompt(context),
            functions: functions
        )
    }

    func getActiveDocumentContext(_ info: EditorInformation) -> ActiveDocumentContext {
        var activeDocumentContext = activeDocumentContext ?? .init(
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
        let start = "User Editing Document Context:###"
        let end = "###"
        let relativePath = "Document Relative Path: \(context.relativePath)"
        let language = "Language: \(context.language)"

        if let focusedContext = context.focusedContext {
            let codeContext = "\(focusedContext.contextRange) \(focusedContext.context)"
            let codeRange = "Focused Range [line, character]: \(focusedContext.codeRange)"
            let code = """
            Focused Code (start from line \(focusedContext.codeRange.start.line)):
            ```\(context.language.rawValue)
            \(focusedContext.code)
            ```
            """
            let fileAnnotations = focusedContext.otherLineAnnotations.isEmpty
                ? ""
                : """
                File Annotations:
                \(focusedContext.otherLineAnnotations.map { "  - \($0)" }.joined(separator: "\n"))
                """
            let codeAnnotations = focusedContext.lineAnnotations.isEmpty
                ? ""
                : """
                Code Annotations:
                \(focusedContext.lineAnnotations.map { "  - \($0)" }.joined(separator: "\n"))
                """
            return [
                start,
                relativePath,
                language,
                fileAnnotations,
                codeContext,
                codeRange,
                codeAnnotations,
                code,
                end,
            ]
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
        } else {
            let selectionRange = "Selection Range [line, character]: \(context.selectionRange)"
            let lineAnnotations = context.lineAnnotations.isEmpty
                ? ""
                : """
                Line Annotations:
                \(context.lineAnnotations.map { "  - \($0)" }.joined(separator: "\n"))
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
}

struct ActiveDocumentContext {
    var relativePath: String
    var language: CodeLanguage
    var fileContent: String
    var lines: [String]
    var selectedCode: String
    var selectionRange: CursorRange
    var lineAnnotations: [EditorInformation.LineAnnotation]
    var imports: [String]

    struct FocusedContext {
        var context: String
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
            if annotation.line >= startLine && annotation.line <= endLine {
                matchedAnnotations.append(annotation)
            } else {
                otherAnnotations.append(annotation)
            }
        }
        
        focusedContext = .init(
            context: {
                switch codeContext.scope {
                case .file:
                    return "File"
                case .top:
                    return "Top level of the file"
                case let .scope(signature):
                    return signature
                }
            }(),
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

