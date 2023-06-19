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
        func countToken(_ message: inout ChatMessage) -> Int {
            if let count = message.tokensCount { return count }
            let count = encoder.countToken(message: message)
            message.tokensCount = count
            return count
        }
        
        var all: [ChatMessage] = []
        let systemMessageTokenCount = countToken(&systemPrompt)
        var allTokensCount = systemPrompt.isEmpty ? 0 : systemMessageTokenCount
        
        for (index, message) in history.enumerated().reversed() {
            if maxNumberOfMessages > 0, all.count >= maxNumberOfMessages { break }
            if message.isEmpty { continue }
            let tokensCount = countToken(&history[index])
            if tokensCount + allTokensCount >
                configuration.maxTokens - configuration.minimumReplyTokens
            {
                break
            }
            allTokensCount += tokensCount
            all.append(message)
        }

        if !systemPrompt.isEmpty {
            all.append(systemPrompt)
        }
        return all.reversed()
    }

    func generateRemainingTokens(
        maxNumberOfMessages: Int = UserDefaults.shared.value(for: \.chatGPTMaxMessageCount),
        encoder: TokenEncoder = AutoManagedChatGPTMemory.encoder
    ) -> Int? {
        // It should be fine to just let OpenAI decide.
        return nil
//        let tokensCount = generateSendingHistory(
//            maxNumberOfMessages: maxNumberOfMessages,
//            encoder: encoder
//        )
//        .reduce(0) { $0 + ($1.tokensCount ?? 0) }
//        return max(configuration.minimumReplyTokens, configuration.maxTokens - tokensCount)
    }

    func setOnHistoryChangeBlock(_ onChange: @escaping () -> Void) {
        onHistoryChange = onChange
    }
}

