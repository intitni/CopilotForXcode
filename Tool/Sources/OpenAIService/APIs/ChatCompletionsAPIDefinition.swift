import AIModel
import ChatBasic
import CodableWrappers
import Foundation
import Preferences

struct ChatCompletionsRequestBody: Equatable {
    struct Message: Equatable {
        enum Role: String, Equatable {
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
        
        struct Image: Equatable {
            enum Format: String {
                case png = "image/png"
                case jpeg = "image/jpeg"
                case gif = "image/gif"
            }
            var data: Data
            var format: Format
            
            var dataURLString: String {
                let base64 = data.base64EncodedString()
                return "data:\(format.rawValue);base64,\(base64)"
            }
        }
        
        struct Audio: Equatable {
            enum Format: String {
                case wav
                case mp3
            }
            
            var data: Data
            var format: Format
        }

        /// The role of the message.
        var role: Role
        /// The content of the message.
        var content: String
        /// When we want to reply to a function call with the result, we have to provide the
        /// name of the function call, and include the result in `content`.
        ///
        /// - important: It's required when the role is `function`.
        var name: String? = nil
        /// Tool calls in an assistant message.
        var toolCalls: [MessageToolCall]? = nil
        /// When we want to call a tool, we have to provide the id of the call.
        ///
        /// - important: It's required when the role is `tool`.
        var toolCallId: String? = nil
        /// Images to include in the message.
        var images: [Image] = []
        /// Audios to include in the message.
        var audios: [Audio] = []
        /// Cache the message if possible.
        var cacheIfPossible: Bool = false
    }

    struct MessageFunctionCall: Equatable {
        /// The name of the
        var name: String
        /// A JSON string.
        var arguments: String?
    }

    struct MessageToolCall: Equatable {
        /// The id of the tool call.
        var id: String
        /// The type of the tool.
        var type: String
        /// The function call.
        var function: MessageFunctionCall
    }

    struct Tool: Equatable {
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

extension ChatCompletionsStreamAPI {
    static func setupExtraHeaderFields(
        _ request: inout URLRequest,
        model: ChatModel,
        apiKey: String
    ) async {
        let parser = HeaderValueParser()
        for field in model.info.customHeaderInfo.headers where !field.key.isEmpty {
            let value = await parser.parse(
                field.value,
                context: .init(modelName: model.info.modelName, apiKey: apiKey)
            )
            request.setValue(value, forHTTPHeaderField: field.key)
        }
    }
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
        var reasoningContent: String?
        var toolCalls: [ToolCall]?
    }

    struct Usage: Codable, Equatable {
        var promptTokens: Int?
        var completionTokens: Int?

        var cachedTokens: Int?
        var otherUsage: [String: Int]
    }

    var id: String?
    var object: String?
    var model: String?
    var message: Delta?
    var finishReason: String?
    var usage: Usage?
}

// MARK: - Non Stream API

protocol ChatCompletionsAPI {
    func callAsFunction() async throws -> ChatCompletionResponseBody
}

struct ChatCompletionResponseBody: Equatable {
    struct Message: Equatable {
        typealias Role = ChatCompletionsRequestBody.Message.Role
        typealias MessageToolCall = ChatCompletionsRequestBody.MessageToolCall

        /// The role of the message.
        var role: Role
        /// The content of the message.
        var content: String?
        /// The reasoning content of the message.
        var reasoningContent: String?
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

    struct Usage: Equatable {
        var promptTokens: Int
        var completionTokens: Int

        var cachedTokens: Int
        var otherUsage: [String: Int]

        mutating func merge(with other: ChatCompletionsStreamDataChunk.Usage) {
            promptTokens += other.promptTokens ?? 0
            completionTokens += other.completionTokens ?? 0
            cachedTokens += other.cachedTokens ?? 0
            for (key, value) in other.otherUsage {
                otherUsage[key, default: 0] += value
            }
        }

        mutating func merge(with other: Self) {
            promptTokens += other.promptTokens
            completionTokens += other.completionTokens
            cachedTokens += other.cachedTokens
            for (key, value) in other.otherUsage {
                otherUsage[key, default: 0] += value
            }
        }
    }

    var id: String?
    var object: String
    var model: String
    var message: Message
    var otherChoices: [Message]
    var finishReason: String
    var usage: Usage?
}

