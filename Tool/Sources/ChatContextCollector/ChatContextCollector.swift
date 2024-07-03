import ChatBasic
import Foundation
import OpenAIService
import Parsing

public struct ChatContext {
    public enum Scope: String, Equatable, CaseIterable, Codable {
        case file
        case code
        case sense
        case project
        case web
    }

    public struct RetrievedContent {
        public var document: ChatMessage.Reference
        public var priority: Int

        public init(document: ChatMessage.Reference, priority: Int) {
            self.document = document
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

public extension ChatContext.Scope {
    init?(text: String) {
        for scope in Self.allCases {
            if scope.rawValue.hasPrefix(text.lowercased()) {
                self = scope
                return
            }
        }
        return nil
    }
}

public protocol ChatContextCollector {
    func generateContext(
        history: [ChatMessage],
        scopes: Set<ChatContext.Scope>,
        content: String,
        configuration: ChatGPTConfiguration
    ) async -> ChatContext
}

public struct MessageScopeParser {
    public init() {}

    public func callAsFunction(_ content: inout String) -> Set<ChatContext.Scope> {
        return parseScopes(&content)
    }

    func parseScopes(_ prompt: inout String) -> Set<ChatContext.Scope> {
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
            return Set(scopes.map(String.init).compactMap(ChatContext.Scope.init(text:)))
        } catch {
            return []
        }
    }
}

