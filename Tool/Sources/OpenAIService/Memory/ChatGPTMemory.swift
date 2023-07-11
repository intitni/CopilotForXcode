import Foundation

public protocol ChatGPTMemory {
    /// The visible messages to the ChatGPT service.
    var messages: [ChatMessage] { get async }
    /// The remaining tokens available for the reply.
    var remainingTokens: Int? { get async }
    /// Update the message history.
    func mutateHistory(_ update: (inout [ChatMessage]) -> Void) async
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
        functionCall: ChatMessage.FunctionCall? = nil,
        summary: String? = nil
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
            } else {
                history.append(.init(
                    id: id,
                    role: role ?? .system,
                    content: content,
                    name: nil,
                    functionCall: functionCall,
                    summary: summary
                ))
            }
        }
    }

    /// Clear the history.
    func clearHistory() async {
        await mutateHistory { $0.removeAll() }
    }
}
