import Foundation
import GPTEncoder
import Preferences

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
    
    public nonisolated
    func observeHistoryChange(_ onChange: @escaping () -> Void) {
        Task {
            await setOnHistoryChangeBlock(onChange)
        }
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

    func setOnHistoryChangeBlock(_ onChange: @escaping () -> Void) {
        onHistoryChange = onChange
    }
}

