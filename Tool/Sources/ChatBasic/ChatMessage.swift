import CodableWrappers
import Foundation

public struct ChatMessage: Equatable, Codable {
    public typealias ID = String

    public enum Role: String, Codable, Equatable {
        case system
        case user
        case assistant
    }

    public struct FunctionCall: Codable, Equatable {
        public var name: String
        public var arguments: String
        public init(name: String, arguments: String) {
            self.name = name
            self.arguments = arguments
        }
    }

    public struct ToolCall: Codable, Equatable, Identifiable {
        public var id: String
        public var type: String
        public var function: FunctionCall
        public var response: ToolCallResponse
        public init(
            id: String,
            type: String,
            function: FunctionCall,
            response: ToolCallResponse? = nil
        ) {
            self.id = id
            self.type = type
            self.function = function
            self.response = response ?? .init(content: "", summary: nil)
        }
    }

    public struct ToolCallResponse: Codable, Equatable {
        public var content: String
        public var summary: String?
        public init(content: String, summary: String?) {
            self.content = content
            self.summary = summary
        }
    }

    public struct Reference: Codable, Equatable {
        public enum Kind: String, Codable {
            case `class`
            case `struct`
            case `enum`
            case `actor`
            case `protocol`
            case `extension`
            case `case`
            case property
            case `typealias`
            case function
            case method
            case text
            case webpage
            case other
        }

        public var title: String
        public var subTitle: String
        public var uri: String
        public var content: String
        public var startLine: Int?
        public var endLine: Int?
        @FallbackDecoding<ReferenceKindFallback>
        public var kind: Kind

        public init(
            title: String,
            subTitle: String,
            content: String,
            uri: String,
            startLine: Int?,
            endLine: Int?,
            kind: Kind
        ) {
            self.title = title
            self.subTitle = subTitle
            self.content = content
            self.uri = uri
            self.startLine = startLine
            self.endLine = endLine
            self.kind = kind
        }
    }

    /// The role of a message.
    @FallbackDecoding<ChatMessageRoleFallback>
    public var role: Role

    /// The content of the message, either the chat message, or a result of a function call.
    public var content: String? {
        didSet { tokensCount = nil }
    }

    /// A function call from the bot.
    public var toolCalls: [ToolCall]? {
        didSet { tokensCount = nil }
    }

    /// The function name of a reply to a function call.
    public var name: String? {
        didSet { tokensCount = nil }
    }

    /// The summary of a message that is used for display.
    public var summary: String?

    /// The id of the message.
    public var id: ID

    /// The number of tokens of this message.
    public var tokensCount: Int?

    /// The references of this message.
    @FallbackDecoding<EmptyArray<Reference>>
    public var references: [Reference]

    /// Is the message considered empty.
    public var isEmpty: Bool {
        if let content, !content.isEmpty { return false }
        if let toolCalls, !toolCalls.isEmpty { return false }
        if let name, !name.isEmpty { return false }
        return true
    }

    public init(
        id: String = UUID().uuidString,
        role: Role,
        content: String?,
        name: String? = nil,
        toolCalls: [ToolCall]? = nil,
        summary: String? = nil,
        tokenCount: Int? = nil,
        references: [Reference] = []
    ) {
        self.role = role
        self.content = content
        self.name = name
        self.toolCalls = toolCalls
        self.summary = summary
        self.id = id
        tokensCount = tokenCount
        self.references = references
    }
}

public struct ReferenceKindFallback: FallbackValueProvider {
    public static var defaultValue: ChatMessage.Reference.Kind { .other }
}

public struct ChatMessageRoleFallback: FallbackValueProvider {
    public static var defaultValue: ChatMessage.Role { .user }
}

