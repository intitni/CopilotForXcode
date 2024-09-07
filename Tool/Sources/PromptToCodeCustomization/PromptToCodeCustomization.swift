import ComposableArchitecture
import Dependencies
import Foundation
import PromptToCodeBasic
import SuggestionBasic
import SwiftUI

public enum PromptToCodeCustomization {
    public static var CustomizedUI: any PromptToCodeCustomizedUI = NoPromptToCodeCustomizedUI()
}

public struct PromptToCodeCustomizationContextWrapper<Content: View>: View {
    @State var context: AnyObject
    let content: (AnyObject) -> Content

    init<O: AnyObject>(context: O, @ViewBuilder content: @escaping (O) -> Content) {
        self.context = context
        self.content = { context in
            content(context as! O)
        }
    }

    public var body: some View {
        content(context)
    }
}

public protocol PromptToCodeCustomizedUI {
    typealias PromptToCodeCustomizedViews = (
        extraMenuItems: AnyView?,
        extraButtons: AnyView?,
        extraAcceptButtonVariants: AnyView?,
        inputField: AnyView?
    )

    func callAsFunction<V: View>(
        state: Shared<PromptToCodeState>,
        isInputFieldFocused: Binding<Bool>,
        @ViewBuilder view: @escaping (PromptToCodeCustomizedViews) -> V
    ) -> PromptToCodeCustomizationContextWrapper<V>
}

struct NoPromptToCodeCustomizedUI: PromptToCodeCustomizedUI {
    private class Context {}

    func callAsFunction<V: View>(
        state: Shared<PromptToCodeState>,
        isInputFieldFocused: Binding<Bool>,
        @ViewBuilder view: @escaping (PromptToCodeCustomizedViews) -> V
    ) -> PromptToCodeCustomizationContextWrapper<V> {
        PromptToCodeCustomizationContextWrapper(context: Context()) { _ in
            view((
                extraMenuItems: nil,
                extraButtons: nil,
                extraAcceptButtonVariants: nil,
                inputField: nil
            ))
        }
    }
}

public struct PromptToCodeState: Equatable {
    public struct Source: Equatable {
        public var language: CodeLanguage
        public var documentURL: URL
        public var projectRootURL: URL
        public var content: String
        public var lines: [String]

        public init(
            language: CodeLanguage,
            documentURL: URL,
            projectRootURL: URL,
            content: String,
            lines: [String]
        ) {
            self.language = language
            self.documentURL = documentURL
            self.projectRootURL = projectRootURL
            self.content = content
            self.lines = lines
        }
    }

    public var source: Source
    public var history: [PromptToCodeHistoryNode] = []
    public var snippets: IdentifiedArrayOf<PromptToCodeSnippet> = []
    public var isGenerating: Bool = false
    public var instruction: String
    public var extraSystemPrompt: String
    public var isAttachedToTarget: Bool = true

    public init(
        source: Source,
        history: [PromptToCodeHistoryNode] = [],
        snippets: IdentifiedArrayOf<PromptToCodeSnippet>,
        instruction: String,
        extraSystemPrompt: String,
        isAttachedToTarget: Bool
    ) {
        self.history = history
        self.snippets = snippets
        isGenerating = false
        self.instruction = instruction
        self.isAttachedToTarget = isAttachedToTarget
        self.extraSystemPrompt = extraSystemPrompt
        self.source = source
    }

    public init(
        source: Source,
        originalCode: String,
        attachedRange: CursorRange,
        instruction: String,
        extraSystemPrompt: String
    ) {
        self.init(
            source: source,
            snippets: [
                .init(
                    startLineIndex: 0,
                    originalCode: originalCode,
                    modifiedCode: originalCode,
                    description: "",
                    error: nil,
                    attachedRange: attachedRange
                ),
            ],
            instruction: instruction,
            extraSystemPrompt: extraSystemPrompt,
            isAttachedToTarget: !attachedRange.isEmpty
        )
    }

    public mutating func popHistory() {
        if !history.isEmpty {
            let last = history.removeLast()
            snippets = last.snippets
            instruction = last.instruction
        }
    }

    public mutating func pushHistory() {
        history.append(.init(snippets: snippets, instruction: instruction))
        let oldSnippets = snippets
        snippets = IdentifiedArrayOf()
        for var snippet in oldSnippets {
            snippet.originalCode = snippet.modifiedCode
            snippet.modifiedCode = ""
            snippet.description = ""
            snippet.error = nil
            snippets.append(snippet)
        }
    }
}

