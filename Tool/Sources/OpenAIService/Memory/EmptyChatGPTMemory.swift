import Foundation

public actor EmptyChatGPTMemory: ChatGPTMemory {
    public var messages: [ChatMessage] = []
    public var remainingTokens: Int? { nil }

    public init() {}

    public func mutateHistory(_ update: (inout [ChatMessage]) -> Void) {
        update(&messages)
    }
    
    public func refresh() async {}
}

