import ComposableArchitecture
import Dependencies
import Foundation
import ModificationBasic
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
        state: Shared<ModificationState>,
        isInputFieldFocused: Binding<Bool>,
        @ViewBuilder view: @escaping (PromptToCodeCustomizedViews) -> V
    ) -> PromptToCodeCustomizationContextWrapper<V>
}

struct NoPromptToCodeCustomizedUI: PromptToCodeCustomizedUI {
    private class Context {}

    func callAsFunction<V: View>(
        state: Shared<ModificationState>,
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

public struct ModificationState: Equatable {
    public typealias Source = ModificationAgentRequest.ModificationSource

    public var source: Source
    public var history: [ModificationHistoryNode] = []
    public var snippets: IdentifiedArrayOf<ModificationSnippet> = []
    public var isGenerating: Bool = false
    public var instruction: String
    public var extraSystemPrompt: String
    public var isAttachedToTarget: Bool = true

    public init(
        source: Source,
        history: [ModificationHistoryNode] = [],
        snippets: IdentifiedArrayOf<ModificationSnippet>,
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

