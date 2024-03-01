import AIModel
import Foundation
import Preferences

/// https://platform.openai.com/docs/api-reference/chat/create
struct ChatCompletionsRequestBody: Codable, Equatable {
    struct Message: Codable, Equatable {
        /// The role of the message.
        var role: ChatMessage.Role
        /// The content of the message.
        var content: String
        /// When we want to reply to a function call with the result, we have to provide the
        /// name of the function call, and include the result in `content`.
        ///
        /// - important: It's required when the role is `function`.
        var name: String?
        /// When the bot wants to call a function, it will reply with a function call in format:
        /// ```json
        /// {
        ///   "name": "weather",
        ///   "arguments": "{ \"location\": \"earth\" }"
        /// }
        /// ```
        var function_call: ChatCompletionsRequestBody.MessageFunctionCall?
    }

    struct MessageFunctionCall: Codable, Equatable {
        /// The name of the
        var name: String
        /// A JSON string.
        var arguments: String?
    }

    struct Function: Codable {
        var name: String
        var description: String
        /// JSON schema.
        var arguments: String
    }

    var model: String
    var messages: [Message]
    var temperature: Double?
    var top_p: Double?
    var n: Double?
    var stream: Bool?
    var stop: [String]?
    var max_tokens: Int?
    var presence_penalty: Double?
    var frequency_penalty: Double?
    var logit_bias: [String: Double]?
    var user: String?
    /// Pass nil to let the bot decide.
    var function_call: FunctionCallStrategy?
    var functions: [ChatGPTFunctionSchema]?

    init(
        model: String,
        messages: [Message],
        temperature: Double? = nil,
        top_p: Double? = nil,
        n: Double? = nil,
        stream: Bool? = nil,
        stop: [String]? = nil,
        max_tokens: Int? = nil,
        presence_penalty: Double? = nil,
        frequency_penalty: Double? = nil,
        logit_bias: [String: Double]? = nil,
        user: String? = nil,
        function_call: FunctionCallStrategy? = nil,
        functions: [ChatGPTFunctionSchema] = []
    ) {
        self.model = model
        self.messages = messages
        self.temperature = temperature
        self.top_p = top_p
        self.n = n
        self.stream = stream
        self.stop = stop
        self.max_tokens = max_tokens
        self.presence_penalty = presence_penalty
        self.frequency_penalty = frequency_penalty
        self.logit_bias = logit_bias
        self.user = user
        if UserDefaults.shared.value(for: \.disableFunctionCalling) {
            self.function_call = nil
            self.functions = nil
        } else {
            self.function_call = function_call
            self.functions = functions.isEmpty ? nil : functions
        }
    }
}

public enum FunctionCallStrategy: Codable, Equatable {
    /// Forbid the bot to call any function.
    case none
    /// Let the bot choose what function to call.
    case auto
    /// Force the bot to call a function with the given name.
    case name(String)

    struct CallFunctionNamed: Codable {
        var name: String
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .none:
            try container.encode("none")
        case .auto:
            try container.encode("auto")
        case let .name(name):
            try container.encode(CallFunctionNamed(name: name))
        }
    }
}

// MARK: - Stream API

typealias ChatCompletionsStreamAPIBuilder = (
    String,
    ChatModel,
    URL,
    ChatCompletionsRequestBody,
    ChatGPTPrompt
) -> any ChatCompletionsStreamAPI

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

struct ChatCompletionsStreamDataChunk: Codable {
    var id: String?
    var object: String?
    var model: String?
    var choices: [Choice]?

    struct Choice: Codable {
        var delta: Delta?
        var index: Int?
        var finish_reason: String?

        struct Delta: Codable {
            struct FunctionCall: Codable {
                var name: String?
                var arguments: String?
            }

            var role: ChatMessage.Role?
            var content: String?
            var function_call: FunctionCall?
        }
    }
}

// MARK: - Non Stream API

typealias ChatCompletionsAPIBuilder = (
    String,
    ChatModel,
    URL,
    ChatCompletionsRequestBody,
    ChatGPTPrompt
)
    -> any ChatCompletionsAPI

protocol ChatCompletionsAPI {
    func callAsFunction() async throws -> ChatCompletionResponseBody
}

/// https://platform.openai.com/docs/api-reference/chat/create
struct ChatCompletionResponseBody: Codable, Equatable {
    struct Message: Codable, Equatable {
        /// The role of the message.
        var role: ChatMessage.Role
        /// The content of the message.
        var content: String?
        /// When we want to reply to a function call with the result, we have to provide the
        /// name of the function call, and include the result in `content`.
        ///
        /// - important: It's required when the role is `function`.
        var name: String?
        /// When the bot wants to call a function, it will reply with a function call in format:
        /// ```json
        /// {
        ///   "name": "weather",
        ///   "arguments": "{ \"location\": \"earth\" }"
        /// }
        /// ```
        var function_call: ChatCompletionsRequestBody.MessageFunctionCall?
    }

    struct Choice: Codable, Equatable {
        var message: Message
        var index: Int
        var finish_reason: String
    }

    struct Usage: Codable, Equatable {
        var prompt_tokens: Int
        var completion_tokens: Int
        var total_tokens: Int
    }

    var id: String?
    var object: String
    var model: String
    var usage: Usage
    var choices: [Choice]
}

