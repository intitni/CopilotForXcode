import ChatBasic
import Foundation

/// A singleton that stores all the possible capabilities of an ``RAGChatAgent``.
public enum RAGChatAgentCapabilityContainer {
    static var capabilities: [String: any RAGChatAgentCapability] = [:]
    static func add(_ capability: any RAGChatAgentCapability) {
        capabilities[capability.id] = capability
    }

    static func add(_ capabilities: [any RAGChatAgentCapability]) {
        capabilities.forEach { add($0) }
    }
}

/// A protocol that defines the capability of an ``RAGChatAgent``.
protocol RAGChatAgentCapability: Identifiable {
    typealias Request = ChatAgentRequest
    typealias Reference = ChatAgentContext.Reference

    /// The name to be displayed to the user.
    var name: String { get }
    /// The identifier of the capability.
    var id: String { get }
    /// Fetch the context for a given request. It can return a portion of the context at a time.
    func fetchContext(for request: ChatAgentRequest) async -> AsyncStream<ChatAgentContext>
}

public struct ChatAgentContext {
    public typealias Reference = ChatMessage.Reference

    /// Extra system prompt to be included in the chat request.
    public var extraSystemPrompt: String?
    /// References to be included in the chat request.
    public var references: [Reference]
    /// Functions to be included in the chat request.
    public var functions: [any ChatGPTFunction]

    public init(
        extraSystemPrompt: String? = nil,
        references: [ChatMessage.Reference] = [],
        functions: [any ChatGPTFunction] = []
    ) {
        self.extraSystemPrompt = extraSystemPrompt
        self.references = references
        self.functions = functions
    }
}

// MARK: - Default Implementation

extension RAGChatAgentCapability {
    func fetchContext(for request: ChatAgentRequest) async -> AsyncStream<ChatAgentContext> {
        return AsyncStream { continuation in
            continuation.finish()
        }
    }
}

