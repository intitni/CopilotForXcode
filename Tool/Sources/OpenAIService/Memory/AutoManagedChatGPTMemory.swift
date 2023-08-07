import Foundation
import Preferences
import TokenEncoder

/// A memory that automatically manages the history according to max tokens and max message count.
public actor AutoManagedChatGPTMemory: ChatGPTMemory {
    public private(set) var messages: [ChatMessage] = []
    public private(set) var remainingTokens: Int? = nil

    public var systemPrompt: ChatMessage
    public var history: [ChatMessage] = [] {
        didSet { onHistoryChange() }
    }

    public var configuration: ChatGPTConfiguration
    public var functionProvider: ChatGPTFunctionProvider

    static let encoder: TokenEncoder = TiktokenCl100kBaseTokenEncoder()

    var onHistoryChange: () -> Void = {}

    public init(
        systemPrompt: String,
        configuration: ChatGPTConfiguration,
        functionProvider: ChatGPTFunctionProvider
    ) {
        self.systemPrompt = .init(role: .system, content: systemPrompt)
        self.configuration = configuration
        self.functionProvider = functionProvider
        _ = Self.encoder // force pre-initialize
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
    
    public func refresh() async {
        messages = generateSendingHistory()
        remainingTokens = generateRemainingTokens()
    }

    /// https://github.com/openai/openai-cookbook/blob/main/examples/How_to_count_tokens_with_tiktoken.ipynb
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
        let functionTokenCount = functionProvider.functions.reduce(into: 0) { partial, function in
            var count = encoder.countToken(text: function.name)
                + encoder.countToken(text: function.description)
            if let data = try? JSONEncoder().encode(function.argumentSchema),
               let string = String(data: data, encoding: .utf8)
            {
                count += encoder.countToken(text: string)
            }
            partial += count
        }
        var allTokensCount = functionTokenCount + 3 // every reply is primed with <|start|>assistant<|message|>
        allTokensCount += systemPrompt.isEmpty ? 0 : systemMessageTokenCount

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
    }

    func setOnHistoryChangeBlock(_ onChange: @escaping () -> Void) {
        onHistoryChange = onChange
    }
}

extension TokenEncoder {
    /// https://github.com/openai/openai-cookbook/blob/main/examples/How_to_count_tokens_with_tiktoken.ipynb
    func countToken(message: ChatMessage) -> Int {
        var total = 3
        if let content = message.content {
            total += encode(text: content).count
        }
        if let name = message.name {
            total += encode(text: name).count
            total += 1
        }
        if let functionCall = message.functionCall {
            total += encode(text: functionCall.name).count
            total += encode(text: functionCall.arguments).count
        }
        return total
    }
}

