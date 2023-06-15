import Foundation

public actor ConversationChatGPTMemory: ChatGPTMemory {
    public var messages: [ChatMessage] = []
    public var remainingTokens: Int? { nil }

    public init(systemPrompt: String) {
        messages.append(.init(role: .system, content: systemPrompt))
    }

    public func mutateHistory(_ update: (inout [ChatMessage]) -> Void) {
        update(&messages)
    }
}
