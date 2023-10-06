import Foundation
import OpenAIService

public struct ChatContext {
    public struct RetrievedContent {
        public enum Priority: Equatable, Comparable {
            case low
            case medium
            case high
            case custom(Int)

            public var rawValue: Int {
                switch self {
                case .low:
                    return 20
                case .medium:
                    return 60
                case .high:
                    return 80
                case let .custom(value):
                    return value
                }
            }

            public static func < (lhs: Self, rhs: Self) -> Bool {
                lhs.rawValue < rhs.rawValue
            }

            public static func == (lhs: Self, rhs: Self) -> Bool {
                lhs.rawValue == rhs.rawValue
            }
        }

        public var content: String
        public var priority: Priority

        public init(content: String, priority: Priority) {
            self.content = content
            self.priority = priority
        }
    }

    public var systemPrompt: String
    public var retrievedContent: [RetrievedContent]
    public var functions: [any ChatGPTFunction]
    public init(
        systemPrompt: String,
        retrievedContent: [RetrievedContent],
        functions: [any ChatGPTFunction]
    ) {
        self.systemPrompt = systemPrompt
        self.retrievedContent = retrievedContent
        self.functions = functions
    }

    public static var empty: Self {
        .init(systemPrompt: "", retrievedContent: [], functions: [])
    }
}

public func + (
    lhs: ChatContext.RetrievedContent.Priority,
    rhs: Int
) -> ChatContext.RetrievedContent.Priority {
    .custom(lhs.rawValue + rhs)
}

public func - (
    lhs: ChatContext.RetrievedContent.Priority,
    rhs: Int
) -> ChatContext.RetrievedContent.Priority {
    .custom(lhs.rawValue - rhs)
}

public protocol ChatContextCollector {
    func generateContext(
        history: [ChatMessage],
        scopes: Set<String>,
        content: String,
        configuration: ChatGPTConfiguration
    ) async -> ChatContext
}

