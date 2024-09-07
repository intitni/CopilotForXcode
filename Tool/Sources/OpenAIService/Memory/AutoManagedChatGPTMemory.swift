import ChatBasic
import Foundation
import Logger
import Preferences
import TokenEncoder

@globalActor
public enum AutoManagedChatGPTMemoryActor: GlobalActor {
    public actor Actor {}
    public static let shared = Actor()
}

protocol AutoManagedChatGPTMemoryStrategy {
    func countToken(_ message: ChatMessage) async -> Int
    func countToken<F: ChatGPTFunction>(_ function: F) async -> Int
}

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
    public var maxNumberOfMessages: Int

    var onHistoryChange: () -> Void = {}

    let composeHistory: HistoryComposer

    public init(
        systemPrompt: String,
        configuration: ChatGPTConfiguration,
        functionProvider: ChatGPTFunctionProvider,
        maxNumberOfMessages: Int = .max,
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
        self.maxNumberOfMessages = maxNumberOfMessages
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
        let strategy: AutoManagedChatGPTMemoryStrategy = switch configuration.model?.format {
        case .googleAI: GoogleAIStrategy(configuration: configuration)
        default: OpenAIStrategy()
        }
        return await generateSendingHistory(strategy: strategy)
    }

    func setOnHistoryChangeBlock(_ onChange: @escaping () -> Void) {
        onHistoryChange = onChange
    }
}

extension AutoManagedChatGPTMemory {
    /// https://github.com/openai/openai-cookbook/blob/main/examples/How_to_count_tokens_with_tiktoken.ipynb
    func generateSendingHistory(strategy: AutoManagedChatGPTMemoryStrategy) async -> ChatGPTPrompt {
        // handle no function support models

        let (
            systemPromptMessage,
            contextSystemPromptMessage,
            availableTokenCountForMessages,
            mandatoryUsage
        ) = await generateMandatoryMessages(strategy: strategy)

        let (
            historyMessage,
            newMessage,
            availableTokenCountForRetrievedContent,
            messageUsage
        ) = await generateMessageHistory(
            maxNumberOfMessages: maxNumberOfMessages - 1, // for the new message
            maxTokenCount: availableTokenCountForMessages,
            strategy: strategy
        )

        let (
            retrievedContentMessage,
            _,
            retrievedContentUsage,
            retrievedContent
        ) = await generateRetrievedContentMessage(
            maxTokenCount: availableTokenCountForRetrievedContent,
            strategy: strategy
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

        return .init(
            history: allMessages,
            references: retrievedContent
        )
    }

    func generateMandatoryMessages(strategy: AutoManagedChatGPTMemoryStrategy) async -> (
        systemPrompt: ChatMessage,
        contextSystemPrompt: ChatMessage,
        remainingTokenCount: Int,
        usage: (systemPrompt: Int, contextSystemPrompt: Int, functions: Int)
    ) {
        let smallestSystemPromptMessage = ChatMessage(
            role: .system,
            content: systemPrompt
        )
        let contextSystemPromptMessage = ChatMessage(
            role: .user,
            content: contextSystemPrompt
        )
        let smallestSystemMessageTokenCount = await strategy
            .countToken(smallestSystemPromptMessage)
        let contextSystemPromptTokenCount = !contextSystemPrompt.isEmpty
            ? (await strategy.countToken(contextSystemPromptMessage))
            : 0

        let functionTokenCount = await {
            var totalTokenCount = 0
            for function in self.functionProvider.functions {
                totalTokenCount += await strategy.countToken(function)
            }
            return totalTokenCount
        }()

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
        strategy: AutoManagedChatGPTMemoryStrategy
    ) async -> (
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
            let tokensCount = await strategy.countToken(message)
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
        strategy: AutoManagedChatGPTMemoryStrategy
    ) async -> (
        retrievedContent: ChatMessage,
        remainingTokenCount: Int,
        usage: Int,
        references: [ChatMessage.Reference]
    ) {
        /// the available tokens count for retrieved content
        let thresholdMaxTokenCount = min(maxTokenCount, configuration.maxTokens / 2)
        /// A separator that costs only 1 token
        let separator = String(repeating: "=", count: 32)
        let retrievedContent = retrievedContent.filter { !$0.content.isEmpty }

        func buildMessage(retrievedContent: [ChatMessage.Reference]) -> ChatMessage {
            var text = ""
            for (index, content) in retrievedContent.enumerated() {
                if index == 0 {
                    text += """
                    Here are the information you know about the system and the project, \
                    separated by \(separator)
                    """
                }

                text += "\n\n\(separator)[DOCUMENT \(index)]\n\n" + content.content
            }

            return .init(role: .user, content: text)
        }

        func buildMessageThatFits() async
            -> (message: ChatMessage, references: [ChatMessage.Reference], tokenCount: Int)
        {
            var right = retrievedContent.count
            var left = 0
            var gappedRetrievedContent = retrievedContent
            var tokenCount: Int?
            var proposedMessage = buildMessage(retrievedContent: [])

            func checkValid(proposedMessage: ChatMessage) async
                -> (isValid: Bool, tokenCount: Int?)
            {
                // if the size is way below the threshold
                let characterCount = proposedMessage.content?.count ?? 0

                if characterCount <= thresholdMaxTokenCount {
                    return (true, nil) // guessing token count.
                }

                let tokensCount = await strategy.countToken(proposedMessage)
                if tokensCount <= thresholdMaxTokenCount {
                    return (true, tokenCount)
                }
                return (false, tokenCount)
            }

            // check if all retrieved content included
            let maxMessage = buildMessage(retrievedContent: retrievedContent)
            let (isValid, maxTokenCount) = await checkValid(proposedMessage: maxMessage)
            if isValid {
                let tokenCount = if let maxTokenCount { maxTokenCount }
                else { await strategy.countToken(maxMessage) }
                return (maxMessage, retrievedContent, tokenCount)
            }

            // binary search to reduce countToken calls
            while left <= right {
                let count = (right + left) / 2
                let _retrievedContent = Array(retrievedContent.prefix(count))
                let _proposedMessage = buildMessage(retrievedContent: _retrievedContent)
                let (isValid, _tokenCount) = await checkValid(proposedMessage: _proposedMessage)
                if isValid {
                    proposedMessage = _proposedMessage
                    gappedRetrievedContent = _retrievedContent
                    tokenCount = _tokenCount
                    left = count + 1
                } else {
                    right = count - 1
                }
            }

            let finalCount = if let tokenCount {
                tokenCount
            } else if proposedMessage.content?.isEmpty ?? true {
                0
            } else {
                await strategy.countToken(proposedMessage)
            }
            return (proposedMessage, gappedRetrievedContent, finalCount)
        }

        let (message, references, tokensCount) = await buildMessageThatFits()

        return (
            message,
            maxTokenCount - tokensCount,
            tokensCount,
            references
        )
    }
}

