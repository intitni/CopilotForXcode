import ChatBasic
import ChatContextCollector
import Foundation
import OpenAIService

public final class WebChatContextCollector: ChatContextCollector {
    var recentLinks = [String]()

    public init() {}

    public func generateContext(
        history: [ChatMessage],
        scopes: Set<ChatContext.Scope>,
        content: String,
        configuration: ChatGPTConfiguration
    ) -> ChatContext {
        guard scopes.contains(.web) else { return .empty }
        let links = Self.detectLinks(from: history) + Self.detectLinks(from: content)
        let functions: [(any ChatGPTFunction)?] = [
            SearchFunction(maxTokens: configuration.maxTokens),
            // allow this function only when there is a link in the memory.
            links.isEmpty ? nil : QueryWebsiteFunction(),
        ]
        return .init(
            systemPrompt: "You prefer to answer questions with latest content on the internet.",
            retrievedContent: [],
            functions: functions.compactMap { $0 }
        )
    }
}

extension WebChatContextCollector {
    static func detectLinks(from messages: [ChatMessage]) -> [String] {
        return messages.lazy
            .compactMap {
                $0.content ?? $0.toolCalls?.map(\.function.arguments).joined(separator: " ") ?? ""
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

