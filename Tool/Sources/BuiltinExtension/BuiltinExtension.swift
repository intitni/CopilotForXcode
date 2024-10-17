import ChatBasic
import ChatTab
import CopilotForXcodeKit
import Foundation
import Preferences

public protocol BuiltinExtension: CopilotForXcodeExtensionCapability {
    /// An identifier for the extension.
    var extensionIdentifier: String { get }

    /// All chat builders provided by this extension.
    var chatTabTypes: [any CustomChatTab] { get }

    /// It's usually called when the app is about to quit,
    /// you should clean up all the resources here.
    func terminate()
}

// MARK: - Default Implementation

public extension BuiltinExtension {
    var suggestionServiceId: BuiltInSuggestionFeatureProvider? { nil }
    var chatTabTypes: [any CustomChatTab] { [] }
}

// MAKR: - ChatService

/// A temporary protocol for ChatServiceType. Migrate it to CopilotForXcodeKit when finished.
public protocol BuiltinExtensionChatServiceType: ChatServiceType {
    typealias Message = ChatMessage

    func sendMessage(
        _ message: String,
        history: [Message],
        references: [RetrievedContent],
        workspace: WorkspaceInfo
    ) async -> AsyncThrowingStream<String, Error>
}

public struct RetrievedContent {
    public var document: ChatMessage.Reference
    public var priority: Int

    public init(document: ChatMessage.Reference, priority: Int) {
        self.document = document
        self.priority = priority
    }
}

public enum ChatServiceMemoryMutation: Codable {
    public typealias Message = ChatMessage

    /// Add a new message to the end of memory.
    /// If an id is not provided, a new id will be generated.
    /// If an id is provided, and a message with the same id exists the message with the same
    /// id will be updated.
    case appendMessage(id: String?, role: Message.Role, text: String)
    /// Update the message with the given id.
    case updateMessage(id: String, role: Message.Role, text: String)
    /// Stream the content into a message with the given id.
    case streamIntoMessage(id: String, role: Message.Role?, text: String?)
}

public protocol CustomChatTab {
    var name: String { get }
    var isDefaultChatTabReplacement: Bool { get }
    var canHandleOpenChatCommand: Bool { get }
    func chatBuilders() -> [ChatTabBuilder]
    func defaultChatBuilder() -> ChatTabBuilder
    func restore(from data: Data) async throws -> any ChatTabBuilder
}

public struct TypedCustomChatTab: CustomChatTab {
    public let type: ChatTab.Type

    public init(of type: ChatTab.Type) {
        self.type = type
    }

    public var name: String { type.name }
    public var isDefaultChatTabReplacement: Bool { type.isDefaultChatTabReplacement }
    public var canHandleOpenChatCommand: Bool { type.canHandleOpenChatCommand }
    public func chatBuilders() -> [ChatTabBuilder] { type.chatBuilders() }
    public func defaultChatBuilder() -> ChatTabBuilder { type.defaultChatBuilder() }
    public func restore(from data: Data) async throws -> any ChatTabBuilder {
        try await type.restore(from: data)
    }
}

