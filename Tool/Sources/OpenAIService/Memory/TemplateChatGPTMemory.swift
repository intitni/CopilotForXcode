import ChatBasic
import Foundation
import Logger
import Preferences
import TokenEncoder

/// A memory that automatically manages the history according to max tokens and the template rules.
public actor TemplateChatGPTMemory: ChatGPTMemory {
    public private(set) var memoryTemplate: MemoryTemplate
    public var history: [ChatMessage] { memoryTemplate.resolved() }
    public var configuration: ChatGPTConfiguration
    public var functionProvider: ChatGPTFunctionProvider

    public init(
        memoryTemplate: MemoryTemplate,
        configuration: ChatGPTConfiguration,
        functionProvider: ChatGPTFunctionProvider
    ) {
        self.memoryTemplate = memoryTemplate
        self.configuration = configuration
        self.functionProvider = functionProvider
    }

    public func mutateHistory(_ update: (inout [ChatMessage]) -> Void) async {
        update(&memoryTemplate.followUpMessages)
    }

    public func generatePrompt() async -> ChatGPTPrompt {
        let strategy: AutoManagedChatGPTMemoryStrategy = switch configuration.model?.format {
        case .googleAI: AutoManagedChatGPTMemory.GoogleAIStrategy(configuration: configuration)
        default: AutoManagedChatGPTMemory.OpenAIStrategy()
        }

        var memoryTemplate = self.memoryTemplate
        func checkTokenCount() async -> Bool {
            let history = memoryTemplate.resolved()
            var tokenCount = 0
            for message in history {
                tokenCount += await strategy.countToken(message)
            }
            for function in functionProvider.functions {
                tokenCount += await strategy.countToken(function)
            }
            return tokenCount <= configuration.maxTokens - configuration.minimumReplyTokens
        }

        while !(await checkTokenCount()) {
            do {
                try await memoryTemplate.truncate()
            } catch {
                Logger.service.error("Failed to truncate prompt template: \(error)")
                break
            }
        }

        return ChatGPTPrompt(history: memoryTemplate.resolved())
    }
}

public struct MemoryTemplate {
    public struct Message {
        public struct DynamicContent: ExpressibleByStringLiteral {
            public enum Content: ExpressibleByStringLiteral {
                case text(String)
                case list([String], formatter: ([String]) -> String)
                case priorityList(
                    [(content: String, priority: Int)],
                    formatter: ([String]) -> String
                )

                public init(stringLiteral value: String) {
                    self = .text(value)
                }
            }

            public var content: Content
            public var priority: Int
            public var isEmpty: Bool {
                switch content {
                case let .text(text):
                    return text.isEmpty
                case let .list(list, _):
                    return list.isEmpty
                case let .priorityList(list, _):
                    return list.isEmpty
                }
            }

            public init(stringLiteral value: String) {
                content = .text(value)
                priority = .max
            }

            public init(_ content: Content, priority: Int = .max) {
                self.content = content
                self.priority = priority
            }
        }

        public var chatMessage: ChatMessage
        public var dynamicContent: [DynamicContent] = []
        public var priority: Int

        public func resolved() -> ChatMessage? {
            var baseMessage = chatMessage
            guard !dynamicContent.isEmpty else {
                if baseMessage.isEmpty { return nil }
                return baseMessage
            }

            let contents: [String] = dynamicContent.compactMap { content in
                if content.isEmpty { return nil }
                switch content.content {
                case let .text(text):
                    return text
                case let .list(list, formatter):
                    return formatter(list)
                case let .priorityList(list, formatter):
                    return formatter(list.map { $0.0 })
                }
            }
            
            let composedContent = contents.joined(separator: "\n\n")
            if composedContent.isEmpty { return nil }

            baseMessage.content = composedContent
            return baseMessage
        }

        public var isEmpty: Bool {
            if !dynamicContent.isEmpty { return dynamicContent.allSatisfy { $0.isEmpty } }
            if let toolCalls = chatMessage.toolCalls, !toolCalls.isEmpty {
                return false
            }
            if let content = chatMessage.content, !content.isEmpty {
                return false
            }
            return true
        }

        public init(
            chatMessage: ChatMessage,
            dynamicContent: [DynamicContent] = [],
            priority: Int = .max
        ) {
            self.chatMessage = chatMessage
            self.dynamicContent = dynamicContent
            self.priority = priority
        }
    }

    public var messages: [Message]
    public var followUpMessages: [ChatMessage]

    public typealias TruncateRule = (
        _ messages: inout [Message],
        _ followUpMessages: inout [ChatMessage]
    ) async throws -> Void
    
    let truncateRule: TruncateRule?

    public init(
        messages: [Message],
        followUpMessages: [ChatMessage] = [],
        truncateRule: TruncateRule? = nil
    ) {
        self.messages = messages
        self.truncateRule = truncateRule
        self.followUpMessages = followUpMessages
    }

    func resolved() -> [ChatMessage] {
        messages.compactMap { message in message.resolved() } + followUpMessages
    }

    func truncated() async throws -> MemoryTemplate {
        var copy = self
        try await copy.truncate()
        return copy
    }

    mutating func truncate() async throws {
        if let truncateRule = truncateRule {
            try await truncateRule(&messages, &followUpMessages)
            return
        }

        try await Self.defaultTruncateRule()(&messages, &followUpMessages)
    }
    
    public struct DefaultTruncateRuleOptions {
        public var numberOfContentListItemToKeep: (Int) -> Int = { $0 * 2 / 3 }
    }

    public static func defaultTruncateRule(
        options updateOptions: (inout DefaultTruncateRuleOptions) -> Void = { _ in }
    ) -> TruncateRule {
        var options = DefaultTruncateRuleOptions()
        updateOptions(&options)
        return { messages, followUpMessages in
            
            // Remove the oldest followup messages when available.
            
            if followUpMessages.count > 20 {
                followUpMessages.removeFirst(followUpMessages.count / 2)
                return
            }
            
            if followUpMessages.count > 2 {
                if followUpMessages.count.isMultiple(of: 2) {
                    followUpMessages.removeFirst(2)
                } else {
                    followUpMessages.removeFirst(1)
                }
                return
            }
            
            // Remove according to the priority.
            
            var truncatingMessageIndex: Int?
            for (index, message) in messages.enumerated() {
                if message.priority == .max { continue }
                if let previousIndex = truncatingMessageIndex,
                   message.priority < messages[previousIndex].priority
                {
                    truncatingMessageIndex = index
                }
            }
            
            guard let truncatingMessageIndex else { throw CancellationError() }
            var truncatingMessage: Message {
                get { messages[truncatingMessageIndex] }
                set { messages[truncatingMessageIndex] = newValue }
            }
            
            if truncatingMessage.isEmpty {
                messages.remove(at: truncatingMessageIndex)
                return
            }
            
            truncatingMessage.dynamicContent.removeAll(where: { $0.isEmpty })
            
            var truncatingContentIndex: Int?
            for (index, content) in truncatingMessage.dynamicContent.enumerated() {
                if content.isEmpty { continue }
                if let previousIndex = truncatingContentIndex,
                   content.priority < truncatingMessage.dynamicContent[previousIndex].priority
                {
                    truncatingContentIndex = index
                }
            }
            
            guard let truncatingContentIndex else { throw CancellationError() }
            var truncatingContent: Message.DynamicContent {
                get { truncatingMessage.dynamicContent[truncatingContentIndex] }
                set { truncatingMessage.dynamicContent[truncatingContentIndex] = newValue }
            }
            
            switch truncatingContent.content {
            case .text:
                truncatingMessage.dynamicContent.remove(at: truncatingContentIndex)
            case let .list(list, formatter):
                let count = options.numberOfContentListItemToKeep(list.count)
                if count > 0 {
                    truncatingContent.content = .list(
                        Array(list.prefix(count)),
                        formatter: formatter
                    )
                } else {
                    truncatingMessage.dynamicContent.remove(at: truncatingContentIndex)
                }
            case let .priorityList(list, formatter):
                let count = options.numberOfContentListItemToKeep(list.count)
                if count > 0 {
                    let orderedList = list.enumerated()
                    let orderedByPriority = orderedList
                        .sorted { $0.element.priority >= $1.element.priority }
                    let kept = orderedByPriority.prefix(count)
                    let reordered = kept.sorted { $0.offset < $1.offset }
                    truncatingContent.content = .priorityList(
                        Array(reordered.map { $0.element }),
                        formatter: formatter
                    )
                } else {
                    truncatingMessage.dynamicContent.remove(at: truncatingContentIndex)
                }
            }
        }
    }
}

