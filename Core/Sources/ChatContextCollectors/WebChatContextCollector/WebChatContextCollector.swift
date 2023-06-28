import ChatContextCollector
import Foundation
import OpenAIService

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
    static func detectLinks(from messages: [ChatMessage]) -> [String] {
        var links = [String]()
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        for message in messages {
            guard let content = message.content else { continue }
            let matches = detector?.matches(
                in: content,
                options: [],
                range: NSRange(content.startIndex..., in: content)
            )

            for match in matches ?? [] {
                guard let range = Range(match.range, in: content) else { continue }
                let url = content[range]
                links.append(String(url))
            }
        }
        return links
    }
}

