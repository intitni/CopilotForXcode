import Foundation
import GPTEncoder

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
        await mutateHistory {
            $0.append(message)
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
    func streamMessage(id: String, role: ChatMessage.Role?, content: String?) async {
        await mutateHistory { history in
            if let index = history.firstIndex(where: { $0.id == id }) {
                if let content {
                    history[index].content.append(content)
                }
                if let role {
                    history[index].role = role
                }
            } else {
                history.append(.init(
                    id: id,
                    role: role ?? .system,
                    content: content ?? ""
                ))
            }
        }
    }

    /// Clear the history.
    func clearHistory() async {
        await mutateHistory { $0.removeAll() }
    }
}

