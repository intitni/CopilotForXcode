import Foundation
import OpenAIService

public struct ChatContext {
    public struct RetrievedPrompt {
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

    public var systemPrompt: [RetrievedPrompt]
    public var functions: [any ChatGPTFunction]
    public init(systemPrompt: [RetrievedPrompt], functions: [any ChatGPTFunction]) {
        self.systemPrompt = systemPrompt
        self.functions = functions
    }
    
    public static var empty: Self {
        .init(systemPrompt: [], functions: [])
    }
}

public func + (
    lhs: ChatContext.RetrievedPrompt.Priority,
    rhs: Int
) -> ChatContext.RetrievedPrompt.Priority {
    .custom(lhs.rawValue + rhs)
}

public func - (
    lhs: ChatContext.RetrievedPrompt.Priority,
    rhs: Int
) -> ChatContext.RetrievedPrompt.Priority {
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

