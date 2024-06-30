import ChatBasic
import ChatTab
import CopilotForXcodeKit
import Foundation
import Preferences

public protocol BuiltinExtension: CopilotForXcodeExtensionCapability {
    /// An id that let the extension manager determine whether the extension is in use.
    var suggestionServiceId: BuiltInSuggestionFeatureProvider { get }
    /// An identifier for the extension.
    var extensionIdentifier: String { get }

    /// All chat builders provided by this extension.
    var chatTabTypes: [any ChatTab.Type] { get }

    /// It's usually called when the app is about to quit,
    /// you should clean up all the resources here.
    func terminate()
}

// MARK: - Default Implementation

public extension BuiltinExtension {
    var chatTabTypes: [any ChatTab.Type] { [] }
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

