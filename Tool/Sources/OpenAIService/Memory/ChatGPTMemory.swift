import Foundation

public struct ChatGPTPrompt: Equatable {
    public var history: [ChatMessage]
    public var references: [ChatMessage.Reference]
    public var remainingTokenCount: Int?

    public init(
        history: [ChatMessage],
        references: [ChatMessage.Reference] = [],
        remainingTokenCount: Int? = nil
    ) {
        self.history = history
        self.references = references
        self.remainingTokenCount = remainingTokenCount
    }
}

public protocol ChatGPTMemory {
    /// The message history.
    var history: [ChatMessage] { get async }
    /// Update the message history.
    func mutateHistory(_ update: (inout [ChatMessage]) -> Void) async
    /// Generate prompt that would be send through the API.
    ///
    /// A memory should make sure that the history in the prompt 
    /// doesn't exceed the maximum token count.
    ///
    /// The history can be different from the actual history.
    func generatePrompt() async -> ChatGPTPrompt
}

public extension ChatGPTMemory {
    /// Append a message to the history.
    func appendMessage(_ message: ChatMessage) async {
        await mutateHistory { history in
            if let index = history.firstIndex(where: { $0.id == message.id }) {
                history[index] = message
            } else {
                history.append(message)
            }
        }
    }

    /// Update a message in the history.
    func updateMessage(id: String, _ update: (inout ChatMessage) -> Void) async {
        await mutateHistory { history in
            if let index = history.firstIndex(where: { $0.id == id }) {
                update(&history[index])
            }
        }
    }

    /// Remove a message from the history.
    func removeMessage(_ id: String) async {
        await mutateHistory {
            $0.removeAll { $0.id == id }
        }
    }

    /// Stream a message to the history.
    func streamMessage(
        id: String,
        role: ChatMessage.Role? = nil,
        content: String? = nil,
        name: String? = nil,
        functionCall: ChatMessage.FunctionCall? = nil,
        summary: String? = nil,
        references: [ChatMessage.Reference]? = nil
    ) async {
        await mutateHistory { history in
            if let index = history.firstIndex(where: { $0.id == id }) {
                if let content {
                    if history[index].content == nil {
                        history[index].content = content
                    } else {
                        history[index].content?.append(content)
                    }
                }
                if let role {
                    history[index].role = role
                }
                if let functionCall {
                    if history[index].functionCall == nil {
                        history[index].functionCall = functionCall
                    } else {
                        history[index].functionCall?.name.append(functionCall.name)
                        history[index].functionCall?.arguments.append(functionCall.arguments)
                    }
                }
                if let summary {
                    history[index].summary = summary
                }
                if let references {
                    history[index].references.append(contentsOf: references)
                }
                if let name {
                    history[index].name = name
                }
            } else {
                history.append(.init(
                    id: id,
                    role: role ?? .system,
                    content: content,
                    name: name,
                    functionCall: functionCall,
                    summary: summary,
                    references: references ?? []
                ))
            }
        }
    }

    /// Clear the history.
    func clearHistory() async {
        await mutateHistory { $0.removeAll() }
    }
}

