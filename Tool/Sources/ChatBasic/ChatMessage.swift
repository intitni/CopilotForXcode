import CodableWrappers
import Foundation

/// A chat message that can be sent or received.
public struct ChatMessage: Equatable, Codable {
    public typealias ID = String

    /// The role of a message.
    public enum Role: String, Codable, Equatable {
        case system
        case user
        case assistant
    }

    /// A function call that can be made by the bot.
    public struct FunctionCall: Codable, Equatable {
        /// The name of the function.
        public var name: String
        /// Arguments in the format of a JSON string.
        public var arguments: String
        public init(name: String, arguments: String) {
            self.name = name
            self.arguments = arguments
        }
    }

    /// A tool call that can be made by the bot.
    public struct ToolCall: Codable, Equatable, Identifiable {
        public var id: String
        /// The type of tool call.
        public var type: String
        /// The actual function call.
        public var function: FunctionCall
        /// The response of the function call.
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

    /// The response of a tool call
    public struct ToolCallResponse: Codable, Equatable {
        /// The content of the response.
        public var content: String
        /// The summary of the response to display in UI.
        public var summary: String?
        public init(content: String, summary: String?) {
            self.content = content
            self.summary = summary
        }
    }

    /// A reference to include in a chat message.
    public struct Reference: Codable, Equatable {
        /// The kind of reference.
        public enum Kind: Codable, Equatable {
            public enum Symbol: String, Codable {
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
            }
            /// Code symbol.
            case symbol(Symbol, uri: String, startLine: Int?, endLine: Int?)
            /// Some text.
            case text
            /// A webpage.
            case webpage(uri: String)
            /// A text file.
            case textFile(uri: String)
            /// Other kind of reference.
            case other(kind: String)
        }

        /// The title of the reference.
        public var title: String
        /// The content of the reference.
        public var content: String
        /// The kind of the reference.
        @FallbackDecoding<ReferenceKindFallback>
        public var kind: Kind

        public init(
            title: String,
            content: String,
            kind: Kind
        ) {
            self.title = title
            self.content = content
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
    
    /// The id of the sender of the message.
    public var senderId: String?
    
    /// The id of the message that this message is a response to.
    public var responseTo: ID?

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
        senderId: String? = nil,
        responseTo: String? = nil,
        role: Role,
        content: String?,
        name: String? = nil,
        toolCalls: [ToolCall]? = nil,
        summary: String? = nil,
        tokenCount: Int? = nil,
        references: [Reference] = []
    ) {
        self.role = role
        self.senderId = senderId
        self.responseTo = responseTo
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
    public static var defaultValue: ChatMessage.Reference.Kind { .other(kind: "Unknown") }
}

public struct ChatMessageRoleFallback: FallbackValueProvider {
    public static var defaultValue: ChatMessage.Role { .user }
}

