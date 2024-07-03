import ChatBasic
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

    func streamToolCallResponse(
        id: String,
        toolCallId: String,
        content: String? = nil,
        summary: String? = nil
    ) async {
        await updateMessage(id: id) { message in
            if let index = message.toolCalls?.firstIndex(where: {
                $0.id == toolCallId
            }) {
                if let content {
                    message.toolCalls?[index].response.content = content
                }
                if let summary {
                    message.toolCalls?[index].response.summary = summary
                }
            }
        }
    }

    /// Stream a message to the history.
    func streamMessage(
        id: String,
        role: ChatMessage.Role? = nil,
        content: String? = nil,
        name: String? = nil,
        toolCalls: [Int: ChatMessage.ToolCall]? = nil,
        summary: String? = nil,
        references: [ChatMessage.Reference]? = nil
    ) async {
        if await history.contains(where: { $0.id == id }) {
            await updateMessage(id: id) { message in
                if let content {
                    if message.content == nil {
                        message.content = content
                    } else {
                        message.content?.append(content)
                    }
                }
                if let role {
                    message.role = role
                }
                if let toolCalls {
                    if var existedToolCalls = message.toolCalls {
                        for pair in toolCalls.sorted(by: { $0.key <= $1.key }) {
                            let (proposedIndex, toolCall) = pair
                            let index = {
                                if toolCall.id.isEmpty { return proposedIndex }
                                return existedToolCalls.lastIndex(where: { $0.id == toolCall.id })
                                    ?? proposedIndex
                            }()
                            if index < existedToolCalls.endIndex {
                                if !toolCall.id.isEmpty {
                                    existedToolCalls[index].id = toolCall.id
                                }
                                if !toolCall.type.isEmpty {
                                    existedToolCalls[index].type = toolCall.type
                                }
                                existedToolCalls[index].function.name
                                    .append(toolCall.function.name)
                                existedToolCalls[index].function.arguments
                                    .append(toolCall.function.arguments)
                            } else {
                                existedToolCalls.append(toolCall)
                            }
                        }
                        message.toolCalls = existedToolCalls
                    } else {
                        message.toolCalls = toolCalls.sorted(by: { $0.key <= $1.key }).map(\.value)
                    }
                }
                if let summary {
                    message.summary = summary
                }
                if let references {
                    message.references.append(contentsOf: references)
                }
                if let name {
                    message.name = name
                }
            }
        } else {
            await mutateHistory { history in
                history.append(.init(
                    id: id,
                    role: role ?? .system,
                    content: content,
                    name: name,
                    toolCalls: toolCalls?.sorted(by: { $0.key <= $1.key }).map(\.value),
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

