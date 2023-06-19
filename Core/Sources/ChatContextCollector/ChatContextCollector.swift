import Foundation
import OpenAIService

public struct ChatContext {
    public var systemPrompt: String
    public var functions: [any ChatGPTFunction]
    public init(systemPrompt: String, functions: [any ChatGPTFunction]) {
        self.systemPrompt = systemPrompt
        self.functions = functions
    }
}

public protocol ChatContextCollector {
    func generateContext(
        history: [ChatMessage],
        scopes: Set<String>,
        content: String
    ) -> ChatContext?
}

