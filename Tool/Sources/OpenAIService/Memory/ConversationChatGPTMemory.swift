import Foundation

public actor ConversationChatGPTMemory: ChatGPTMemory {
    public var history: [ChatMessage] = []

    public init(systemPrompt: String, systemMessageId: String = UUID().uuidString) {
        history.append(.init(id: systemMessageId, role: .system, content: systemPrompt))
    }

    public func mutateHistory(_ update: (inout [ChatMessage]) -> Void) {
        update(&history)
    }
    
    public func generatePrompt() async -> ChatGPTPrompt {
        return .init(history: history)
    }
}

