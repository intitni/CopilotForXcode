import Foundation
import OpenAIService
import Parsing

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

public struct MessageScopeParser {
    public init() {}

    public func callAsFunction(_ content: inout String) -> Set<String> {
        return parseScopes(&content)
    }

    func parseScopes(_ prompt: inout String) -> Set<String> {
        guard !prompt.isEmpty else { return [] }
        do {
            let parser = Parse {
                "@"
                Many {
                    Prefix { $0.isLetter }
                } separator: {
                    "+"
                } terminator: {
                    " "
                }
                Skip {
                    Many {
                        " "
                    }
                }
                Rest()
            }
            let (scopes, rest) = try parser.parse(prompt)
            prompt = String(rest)
            return Set(scopes.map(String.init))
        } catch {
            return []
        }
    }
}

