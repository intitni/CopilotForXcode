import Foundation

public protocol ChatModel {
    func generate(
        prompt: [ChatMessage],
        stops: [String],
        callbackManagers: [ChainCallbackManager]
    ) async throws -> String
}

public struct ChatMessage {
    public enum Role {
        case system
        case user
        case assistant
    }

    public var role: Role
    public var content: String

    public init(role: Role, content: String) {
        self.role = role
        self.content = content
    }
}
