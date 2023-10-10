import Foundation
import OpenAIService

public struct ChatContext {
    public struct RetrievedContent {
        public var content: String
        public var priority: Int

        public init(content: String, priority: Int) {
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

public protocol ChatContextCollector {
    func generateContext(
        history: [ChatMessage],
        scopes: Set<String>,
        content: String,
        configuration: ChatGPTConfiguration
    ) async -> ChatContext
}

