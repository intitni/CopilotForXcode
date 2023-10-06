import Foundation
import Logger
import Preferences
import TokenEncoder

/// A memory that automatically manages the history according to max tokens and max message count.
public actor AutoManagedChatGPTMemory: ChatGPTMemory {
    public private(set) var messages: [ChatMessage] = []
    public private(set) var remainingTokens: Int?

    public var systemPrompt: String
    public var retrievedContent: [String] = []
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
        self.systemPrompt = systemPrompt
        self.configuration = configuration
        self.functionProvider = functionProvider
        _ = Self.encoder // force pre-initialize
    }

    public func mutateHistory(_ update: (inout [ChatMessage]) -> Void) {
        update(&history)
    }

    public func mutateSystemPrompt(_ newPrompt: String) {
        systemPrompt = newPrompt
    }

    public func mutateRetrievedContent(_ newContent: [String]) {
        retrievedContent = newContent
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
    ///
    /// Format:
    /// ```
    /// [System Prompt] priority: high
    ///   [Retrieved Content] priority: low
    ///     [Retrieved Content A]
    ///     <separator>
    ///     [Retrieved Content B]
    /// [Functions] priority: high
    /// [Message History] priority: medium
    /// ```
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

        var smallestSystemPromptMessage = ChatMessage(role: .system, content: systemPrompt)
        let smallestSystemMessageTokenCount = countToken(&smallestSystemPromptMessage)
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
        let mandatoryContentTokensCount = smallestSystemMessageTokenCount
            + functionTokenCount
            + 3 // every reply is primed with <|start|>assistant<|message|>

        /// the available tokens count for other messages and retrieved content
        let availableTokenCountForMessages = configuration.maxTokens
            - configuration.minimumReplyTokens
            - mandatoryContentTokensCount

        var messageTokenCount = 0
        var allMessages: [ChatMessage] = []

        for (index, message) in history.enumerated().reversed() {
            if maxNumberOfMessages > 0, allMessages.count >= maxNumberOfMessages { break }
            if message.isEmpty { continue }
            let tokensCount = countToken(&history[index])
            if tokensCount + messageTokenCount > availableTokenCountForMessages { break }
            messageTokenCount += tokensCount
            allMessages.append(message)
        }

        /// the available tokens count for retrieved content
        let availableTokenCountForRetrievedContent = availableTokenCountForMessages
            - messageTokenCount
        var retrievedContentTokenCount = 0

        let separator = String(repeating: "=", count: 32) // only 1 token

        var systemPrompt = systemPrompt

        func appendToSystemPrompt(_ text: String) -> Bool {
            let tokensCount = encoder.countToken(text: text)
            if tokensCount + retrievedContentTokenCount >
                availableTokenCountForRetrievedContent { return false }
            retrievedContentTokenCount += tokensCount
            systemPrompt += text
            return true
        }

        for (index, content) in retrievedContent.filter({ !$0.isEmpty }).enumerated() {
            if index == 0 {
                if !appendToSystemPrompt("""

                Below are information related to the conversation, separated by \(separator)

                """) { break }
            } else {
                if !appendToSystemPrompt(separator) { break }
            }

            if !appendToSystemPrompt(content) { break }
        }

        if !systemPrompt.isEmpty {
            let message = ChatMessage(role: .system, content: systemPrompt)
            allMessages.append(message)
        }

        #if DEBUG
        Logger.service.info("""
        Sending tokens count
        - system prompt: \(smallestSystemPromptMessage)
        - functions: \(functionTokenCount)
        - messages: \(messageTokenCount)
        - retrieved content: \(retrievedContentTokenCount)
        - total: \(
            smallestSystemMessageTokenCount
                + functionTokenCount
                + messageTokenCount
                + retrievedContentTokenCount
        )

        """)
        #endif

        return allMessages.reversed()
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

