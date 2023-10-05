import ChatContextCollector
import Foundation
import OpenAIService

public final class WebChatContextCollector: ChatContextCollector {
    var recentLinks = [String]()

    public init() {}

    public func generateContext(
        history: [ChatMessage],
        scopes: Set<String>,
        content: String,
        configuration: ChatGPTConfiguration
    ) -> ChatContext {
        guard scopes.contains("web") || scopes.contains("w") else { return .empty }
        let links = Self.detectLinks(from: history) + Self.detectLinks(from: content)
        let functions: [(any ChatGPTFunction)?] = [
            SearchFunction(maxTokens: configuration.maxTokens),
            // allow this function only when there is a link in the memory.
            links.isEmpty ? nil : QueryWebsiteFunction(),
        ]
        return .init(
            systemPrompt: [
                .init(
                    content: "You prefer to answer questions with latest content on the internet.",
                    priority: .low
                ),
            ],
            functions: functions.compactMap { $0 }
        )
    }
}

extension WebChatContextCollector {
    static func detectLinks(from messages: [ChatMessage]) -> [String] {
        return messages.lazy
            .compactMap {
                $0.content ?? $0.functionCall?.arguments
            }
            .map(detectLinks(from:))
            .flatMap { $0 }
    }

    static func detectLinks(from content: String) -> [String] {
        var links = [String]()
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
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
        return links
    }
}

