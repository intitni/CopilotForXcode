import ChatContextCollector
import Foundation
import OpenAIService
import SuggestionModel

public final class WebChatContextCollector: ChatContextCollector {
    var recentLinks = [String]()
    
    public init() {}

    public func generateContext(
        history: [ChatMessage],
        scopes: Set<String>,
        content: String
    ) -> ChatContext? {
        guard scopes.contains("web") else { return nil }
        let links = Self.detectLinks(from: history)
        let functions: [(any ChatGPTFunction)?] = [
            SearchFunction(),
            // allow this function only when there is a link in the memory.
            links.isEmpty ? nil : QueryWebsiteFunction(),
        ]
        return .init(
            systemPrompt: "You prefer to answer questions with latest content on the internet.",
            functions: functions.compactMap { $0 }
        )
    }
}

extension WebChatContextCollector {
    static func detectLinks(from: [ChatMessage]) -> [String] {
        return []
    }
}

