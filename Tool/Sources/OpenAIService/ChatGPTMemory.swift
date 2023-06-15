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

/// A memory that automatically manages the history according to max tokens and max message count.
public actor AutoManagedChatGPTMemory: ChatGPTMemory {
    public var messages: [ChatMessage] { generateSendingHistory() }
    public var remainingTokens: Int? { generateRemainingTokens() }

    public var systemPrompt: ChatMessage
    public var history: [ChatMessage] = [] {
        didSet { onHistoryChange() }
    }

    public var configuration: ChatGPTConfiguration

    static let encoder: TokenEncoder = GPTEncoder()

    var onHistoryChange: () -> Void = {}

    public init(systemPrompt: String, configuration: ChatGPTConfiguration) {
        self.systemPrompt = .init(role: .system, content: systemPrompt)
        self.configuration = configuration
    }

    public func mutateHistory(_ update: (inout [ChatMessage]) -> Void) {
        update(&history)
    }

    public func mutateSystemPrompt(_ newPrompt: String) {
        systemPrompt.content = newPrompt
    }

    func generateSendingHistory(
        maxNumberOfMessages: Int = UserDefaults.shared.value(for: \.chatGPTMaxMessageCount),
        encoder: TokenEncoder = AutoManagedChatGPTMemory.encoder
    ) -> [ChatMessage] {
        var all: [ChatMessage] = []
        let systemMessageTokenCount = systemPrompt.tokensCount
            ?? encoder.encode(text: systemPrompt.content).count
        systemPrompt.tokensCount = systemMessageTokenCount

        var allTokensCount = systemMessageTokenCount
        for (index, message) in history.enumerated().reversed() {
            var message = message
            if maxNumberOfMessages > 0, all.count >= maxNumberOfMessages { break }
            if message.content.isEmpty { continue }
            let tokensCount = message.tokensCount ?? encoder.encode(text: message.content).count
            history[index].tokensCount = tokensCount
            if tokensCount + allTokensCount >
                configuration.maxTokens - configuration.minimumReplyTokens
            {
                break
            }
            message.tokensCount = tokensCount
            allTokensCount += tokensCount
            all.append(message)
        }

        if !systemPrompt.content.isEmpty {
            all.append(systemPrompt)
        }
        return all.reversed()
    }

    func generateRemainingTokens(
        maxNumberOfMessages: Int = UserDefaults.shared.value(for: \.chatGPTMaxMessageCount),
        encoder: TokenEncoder = AutoManagedChatGPTMemory.encoder
    ) -> Int? {
        let tokensCount = generateSendingHistory(
            maxNumberOfMessages: maxNumberOfMessages,
            encoder: encoder
        )
        .reduce(0) { $0 + ($1.tokensCount ?? 0) }
        return max(configuration.minimumReplyTokens, configuration.maxTokens - tokensCount)
    }

    public nonisolated
    func observeHistoryChange(_ onChange: @escaping () -> Void) {
        Task {
            await setOnHistoryChangeBlock(onChange)
        }
    }

    func setOnHistoryChangeBlock(_ onChange: @escaping () -> Void) {
        onHistoryChange = onChange
    }
}

