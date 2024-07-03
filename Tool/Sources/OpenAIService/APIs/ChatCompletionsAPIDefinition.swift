import AIModel
import CodableWrappers
import Foundation
import Preferences
import ChatBasic

struct ChatCompletionsRequestBody: Codable, Equatable {
    struct Message: Codable, Equatable {
        enum Role: String, Codable, Equatable {
            case system
            case user
            case assistant
            case tool
            
            var asChatMessageRole: ChatMessage.Role {
                switch self {
                case .system:
                    return .system
                case .user:
                    return .user
                case .assistant:
                    return .assistant
                case .tool:
                    return .user
                }
            }
        }

        /// The role of the message.
        var role: Role
        /// The content of the message.
        var content: String
        /// When we want to reply to a function call with the result, we have to provide the
        /// name of the function call, and include the result in `content`.
        ///
        /// - important: It's required when the role is `function`.
        var name: String?
        /// Tool calls in an assistant message.
        var toolCalls: [MessageToolCall]?
        /// When we want to call a tool, we have to provide the id of the call.
        ///
        /// - important: It's required when the role is `tool`.
        var toolCallId: String?
    }

    struct MessageFunctionCall: Codable, Equatable {
        /// The name of the
        var name: String
        /// A JSON string.
        var arguments: String?
    }

    struct MessageToolCall: Codable, Equatable {
        /// The id of the tool call.
        var id: String
        /// The type of the tool.
        var type: String
        /// The function call.
        var function: MessageFunctionCall
    }

    struct Tool: Codable, Equatable {
        var type: String = "function"
        var function: ChatGPTFunctionSchema
    }

    var model: String
    var messages: [Message]
    var temperature: Double?
    var stream: Bool?
    var stop: [String]?
    var maxTokens: Int?
    /// Pass nil to let the bot decide.
    var toolChoice: FunctionCallStrategy?
    var tools: [Tool]?

    init(
        model: String,
        messages: [Message],
        temperature: Double? = nil,
        stream: Bool? = nil,
        stop: [String]? = nil,
        maxTokens: Int? = nil,
        toolChoice: FunctionCallStrategy? = nil,
        tools: [Tool] = []
    ) {
        self.model = model
        self.messages = messages
        self.temperature = temperature
        self.stream = stream
        self.stop = stop
        self.maxTokens = maxTokens
        if UserDefaults.shared.value(for: \.disableFunctionCalling) {
            self.toolChoice = nil
            self.tools = nil
        } else {
            self.toolChoice = toolChoice
            self.tools = tools.isEmpty ? nil : tools
        }
    }
}

struct EmptyMessageFunctionCall: FallbackValueProvider {
    static var defaultValue: ChatCompletionsRequestBody.MessageFunctionCall {
        .init(name: "")
    }
}

public enum FunctionCallStrategy: Codable, Equatable {
    /// Forbid the bot to call any function.
    case none
    /// Let the bot choose what function to call.
    case auto
    /// Force the bot to call a function with the given name.
    case function(name: String)

    struct CallFunctionNamed: Codable {
        var type = "function"
        let function: Function
        struct Function: Codable {
            var name: String
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .none:
            try container.encode("none")
        case .auto:
            try container.encode("auto")
        case let .function(name):
            try container.encode(CallFunctionNamed(function: .init(name: name)))
        }
    }
}

// MARK: - Stream API

protocol ChatCompletionsStreamAPI {
    func callAsFunction() async throws -> AsyncThrowingStream<ChatCompletionsStreamDataChunk, Error>
}

extension AsyncSequence {
    func toStream() -> AsyncThrowingStream<Element, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    for try await element in self {
                        continuation.yield(element)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
}

struct ChatCompletionsStreamDataChunk {
    struct Delta {
        struct FunctionCall {
            var name: String?
            var arguments: String?
        }

        struct ToolCall {
            var index: Int?
            var id: String?
            var type: String?
            var function: FunctionCall?
        }

        var role: ChatCompletionsRequestBody.Message.Role?
        var content: String?
        var toolCalls: [ToolCall]?
    }

    var id: String?
    var object: String?
    var model: String?
    var message: Delta?
    var finishReason: String?
}

// MARK: - Non Stream API

protocol ChatCompletionsAPI {
    func callAsFunction() async throws -> ChatCompletionResponseBody
}

struct ChatCompletionResponseBody: Codable, Equatable {
    typealias Message = ChatCompletionsRequestBody.Message

    var id: String?
    var object: String
    var model: String
    var message: Message
    var otherChoices: [Message]
    var finishReason: String
}

