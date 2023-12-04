import Foundation
import Logger
import Preferences
import TokenEncoder

/// A memory that automatically manages the history according to max tokens and max message count.
public actor AutoManagedChatGPTMemory: ChatGPTMemory {
    public struct ComposableMessages {
        public var systemPromptMessage: ChatMessage
        public var historyMessage: [ChatMessage]
        public var retrievedContentMessage: ChatMessage
        public var contextSystemPromptMessage: ChatMessage
        public var newMessage: ChatMessage
    }

    public typealias HistoryComposer = (ComposableMessages) -> [ChatMessage]

    public private(set) var history: [ChatMessage] = [] {
        didSet { onHistoryChange() }
    }

    public private(set) var remainingTokens: Int?

    public var systemPrompt: String
    public var contextSystemPrompt: String
    public var retrievedContent: [ChatMessage.Reference] = []
    public var configuration: ChatGPTConfiguration
    public var functionProvider: ChatGPTFunctionProvider

    static let encoder: TokenEncoder = TiktokenCl100kBaseTokenEncoder()

    var onHistoryChange: () -> Void = {}

    let composeHistory: HistoryComposer

    public init(
        systemPrompt: String,
        configuration: ChatGPTConfiguration,
        functionProvider: ChatGPTFunctionProvider,
        composeHistory: @escaping HistoryComposer = {
            /// Default Format:
            /// ```
            /// [System Prompt] priority: high
            /// [Functions] priority: high
            /// [Retrieved Content] priority: low
            ///     [Retrieved Content A]
            ///     <separator>
            ///     [Retrieved Content B]
            /// [Message History] priority: medium
            /// [Context System Prompt] priority: high
            /// [Latest Message] priority: high
            /// ```
            [$0.systemPromptMessage] +
                $0.historyMessage +
                [$0.retrievedContentMessage, $0.contextSystemPromptMessage, $0.newMessage]
        }
    ) {
        self.systemPrompt = systemPrompt
        contextSystemPrompt = ""
        self.configuration = configuration
        self.functionProvider = functionProvider
        self.composeHistory = composeHistory
        _ = Self.encoder // force pre-initialize
    }

    public func mutateHistory(_ update: (inout [ChatMessage]) -> Void) {
        update(&history)
    }

    public func mutateSystemPrompt(_ newPrompt: String) {
        systemPrompt = newPrompt
    }

    public func mutateContextSystemPrompt(_ newPrompt: String) {
        contextSystemPrompt = newPrompt
    }

    public func mutateRetrievedContent(_ newContent: [ChatMessage.Reference]) {
        retrievedContent = newContent
    }

    public nonisolated
    func observeHistoryChange(_ onChange: @escaping () -> Void) {
        Task {
            await setOnHistoryChangeBlock(onChange)
        }
    }

    public func generatePrompt() async -> ChatGPTPrompt {
        return generateSendingHistory()
    }

    /// https://github.com/openai/openai-cookbook/blob/main/examples/How_to_count_tokens_with_tiktoken.ipynb
    func generateSendingHistory(
        maxNumberOfMessages: Int = UserDefaults.shared.value(for: \.chatGPTMaxMessageCount),
        encoder: TokenEncoder = AutoManagedChatGPTMemory.encoder
    ) -> ChatGPTPrompt {
        let (
            systemPromptMessage,
            contextSystemPromptMessage,
            availableTokenCountForMessages,
            mandatoryUsage
        ) = generateMandatoryMessages(encoder: encoder)

        let (
            historyMessage,
            newMessage,
            availableTokenCountForRetrievedContent,
            messageUsage
        ) = generateMessageHistory(
            maxNumberOfMessages: maxNumberOfMessages - 1, // for the new message
            maxTokenCount: availableTokenCountForMessages,
            encoder: encoder
        )

        let (
            retrievedContentMessage,
            _,
            retrievedContentUsage,
            retrievedContent
        ) = generateRetrievedContentMessage(
            maxTokenCount: availableTokenCountForRetrievedContent,
            encoder: encoder
        )

        let allMessages = composeHistory(.init(
            systemPromptMessage: systemPromptMessage,
            historyMessage: historyMessage,
            retrievedContentMessage: retrievedContentMessage,
            contextSystemPromptMessage: contextSystemPromptMessage,
            newMessage: newMessage
        )).filter {
            !($0.content?.isEmpty ?? false)
        }

        #if DEBUG
        Logger.service.info("""
        Sending tokens count
        - system prompt: \(mandatoryUsage.systemPrompt)
        - context system prompt: \(mandatoryUsage.contextSystemPrompt)
        - functions: \(mandatoryUsage.functions)
        - messages: \(messageUsage)
        - retrieved content: \(retrievedContentUsage)
        - total: \(
            mandatoryUsage.systemPrompt
                + mandatoryUsage.contextSystemPrompt
                + mandatoryUsage.functions
                + messageUsage
                + retrievedContentUsage
        )
        """)
        #endif

        return .init(history: allMessages, references: retrievedContent)
    }

    func setOnHistoryChangeBlock(_ onChange: @escaping () -> Void) {
        onHistoryChange = onChange
    }
}

extension AutoManagedChatGPTMemory {
    func generateMandatoryMessages(encoder: TokenEncoder) -> (
        systemPrompt: ChatMessage,
        contextSystemPrompt: ChatMessage,
        remainingTokenCount: Int,
        usage: (systemPrompt: Int, contextSystemPrompt: Int, functions: Int)
    ) {
        var smallestSystemPromptMessage = ChatMessage(role: .system, content: systemPrompt)
        var contextSystemPromptMessage = ChatMessage(role: .user, content: contextSystemPrompt)
        let smallestSystemMessageTokenCount = encoder.countToken(&smallestSystemPromptMessage)
        let contextSystemPromptTokenCount = !contextSystemPrompt.isEmpty
            ? encoder.countToken(&contextSystemPromptMessage)
            : 0

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
            + contextSystemPromptTokenCount
            + functionTokenCount
            + 3 // every reply is primed with <|start|>assistant<|message|>

        // build messages

        /// the available tokens count for other messages and retrieved content
        let availableTokenCountForMessages = configuration.maxTokens
            - configuration.minimumReplyTokens
            - mandatoryContentTokensCount

        return (
            smallestSystemPromptMessage,
            contextSystemPromptMessage,
            availableTokenCountForMessages,
            (
                smallestSystemMessageTokenCount,
                contextSystemPromptTokenCount,
                functionTokenCount
            )
        )
    }

    func generateMessageHistory(
        maxNumberOfMessages: Int,
        maxTokenCount: Int,
        encoder: TokenEncoder
    ) -> (
        history: [ChatMessage],
        newMessage: ChatMessage,
        remainingTokenCount: Int,
        usage: Int
    ) {
        var messageTokenCount = 0
        var allMessages: [ChatMessage] = []
        var newMessage: ChatMessage?

        for (index, message) in history.enumerated().reversed() {
            if maxNumberOfMessages > 0, allMessages.count >= maxNumberOfMessages { break }
            if message.isEmpty { continue }
            let tokensCount = encoder.countToken(&history[index])
            if tokensCount + messageTokenCount > maxTokenCount { break }
            messageTokenCount += tokensCount
            if index == history.endIndex - 1 {
                newMessage = message
            } else {
                allMessages.append(message)
            }
        }

        return (
            allMessages.reversed(),
            newMessage ?? .init(role: .user, content: ""),
            maxTokenCount - messageTokenCount,
            messageTokenCount
        )
    }

    func generateRetrievedContentMessage(
        maxTokenCount: Int,
        encoder: TokenEncoder
    ) -> (
        retrievedContent: ChatMessage,
        remainingTokenCount: Int,
        usage: Int,
        references: [ChatMessage.Reference]
    ) {
        /// the available tokens count for retrieved content
        let thresholdMaxTokenCount = min(maxTokenCount, configuration.maxTokens / 2)

        var retrievedContentTokenCount = 0
        let separator = String(repeating: "=", count: 32) // only 1 token
        var message = ""
        var references = [ChatMessage.Reference]()

        func appendToMessage(_ text: String) -> Bool {
            let tokensCount = encoder.countToken(text: text)
            if tokensCount + retrievedContentTokenCount > thresholdMaxTokenCount { return false }
            retrievedContentTokenCount += tokensCount
            message += text
            return true
        }

        for (index, content) in retrievedContent.filter({ !$0.content.isEmpty }).enumerated() {
            if index == 0 {
                if !appendToMessage("""
                Here are the information you know about the system and the project, \
                separated by \(separator)


                """) { break }
            } else {
                if !appendToMessage("\n\(separator)\n") { break }
            }

            if !appendToMessage(content.content) { break }
            references.append(content)
        }

        return (
            .init(role: .user, content: message),
            maxTokenCount - retrievedContentTokenCount,
            retrievedContentTokenCount,
            references
        )
    }
}

public extension TokenEncoder {
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

    func countToken(_ message: inout ChatMessage) -> Int {
        if let count = message.tokensCount { return count }
        let count = countToken(message: message)
        message.tokensCount = count
        return count
    }
}

