import Foundation

public actor ConversationChatGPTMemory: ChatGPTMemory {
    public var messages: [ChatMessage] = []
    public var remainingTokens: Int? { nil }

    public init(systemPrompt: String, systemMessageId: String = UUID().uuidString) {
        messages.append(.init(id: systemMessageId, role: .system, content: systemPrompt))
    }

    public func mutateHistory(_ update: (inout [ChatMessage]) -> Void) {
        update(&messages)
    }
    
    public func refresh() async {}
}

