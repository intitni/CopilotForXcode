import ChatContextCollector
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
    typealias Message = ChatServiceMessage
    typealias RetrievedContent = ChatContext.RetrievedContent
}

public struct ChatServiceMessage: Codable {
    public enum Role: Codable, Equatable {
        case system
        case user
        case assistant
        case tool
        case other(String)
    }

    public var role: Role
    public var text: String

    public init(role: Role, text: String) {
        self.role = role
        self.text = text
    }
}

