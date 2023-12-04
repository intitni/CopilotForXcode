import Foundation

public actor EmptyChatGPTMemory: ChatGPTMemory {
    public var history: [ChatMessage] = []

    public init() {}

    public func mutateHistory(_ update: (inout [ChatMessage]) -> Void) {
        update(&history)
    }
    
    public func generatePrompt() async -> ChatGPTPrompt {
        return .init(history: history)
    }
}

