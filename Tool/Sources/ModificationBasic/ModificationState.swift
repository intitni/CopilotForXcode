import ChatBasic
import Foundation
import IdentifiedCollections
import SuggestionBasic

public struct ModificationState {
    public typealias Source = ModificationAgentRequest.ModificationSource

    public var source: Source
    public var history: [ModificationHistoryNode] = []
    public var snippets: IdentifiedArrayOf<ModificationSnippet> = []
    public var isGenerating: Bool = false
    public var extraSystemPrompt: String
    public var isAttachedToTarget: Bool = true
    public var status = [String]()
    public var references: [ChatMessage.Reference] = []

    public init(
        source: Source,
        history: [ModificationHistoryNode] = [],
        snippets: IdentifiedArrayOf<ModificationSnippet>,
        extraSystemPrompt: String,
        isAttachedToTarget: Bool,
        isGenerating: Bool = false,
        status: [String] = [],
        references: [ChatMessage.Reference] = []
    ) {
        self.history = history
        self.snippets = snippets
        self.isGenerating = isGenerating
        self.isAttachedToTarget = isAttachedToTarget
        self.extraSystemPrompt = extraSystemPrompt
        self.source = source
        self.status = status
        self.references = references
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
            extraSystemPrompt: extraSystemPrompt,
            isAttachedToTarget: !attachedRange.isEmpty
        )
    }

    public mutating func popHistory() -> NSAttributedString? {
        if !history.isEmpty {
            let last = history.removeLast()
            references = last.references
            snippets = last.snippets
            let instruction = last.instruction
            return instruction
        }

        return nil
    }

    public mutating func pushHistory(instruction: NSAttributedString) {
        history.append(.init(snippets: snippets, instruction: instruction, references: references))
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

