import AIModel
import AsyncAlgorithms
import Foundation
import Preferences

typealias CompletionStreamAPIBuilder = (
    String,
    ChatModel,
    URL,
    CompletionRequestBody,
    ChatGPTPrompt
) -> any CompletionStreamAPI

protocol CompletionStreamAPI {
    func callAsFunction() async throws -> AsyncThrowingStream<CompletionStreamDataChunk, Error>
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

/// https://platform.openai.com/docs/api-reference/chat/create
struct CompletionRequestBody: Codable, Equatable {
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
        var function_call: CompletionRequestBody.MessageFunctionCall?
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

struct CompletionStreamDataChunk: Codable {
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

struct OpenAICompletionStreamAPI: CompletionStreamAPI {
    var apiKey: String
    var endpoint: URL
    var requestBody: CompletionRequestBody
    var model: ChatModel

    init(
        apiKey: String,
        model: ChatModel,
        endpoint: URL,
        requestBody: CompletionRequestBody
    ) {
        self.apiKey = apiKey
        self.endpoint = endpoint
        self.requestBody = requestBody
        self.requestBody.stream = true
        self.model = model
    }

    func callAsFunction() async throws -> AsyncThrowingStream<CompletionStreamDataChunk, Error> {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(requestBody)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !apiKey.isEmpty {
            switch model.format {
            case .openAI, .openAICompatible:
                request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            case .azureOpenAI:
                request.setValue(apiKey, forHTTPHeaderField: "api-key")
            case .googleAI:
                assertionFailure("Unsupported")
            }
        }

        let (result, response) = try await URLSession.shared.bytes(for: request)
        guard let response = response as? HTTPURLResponse else {
            throw ChatGPTServiceError.responseInvalid
        }

        guard response.statusCode == 200 else {
            let text = try await result.lines.reduce(into: "") { partialResult, current in
                partialResult += current
            }
            guard let data = text.data(using: .utf8)
            else { throw ChatGPTServiceError.responseInvalid }
            let decoder = JSONDecoder()
            let error = try? decoder.decode(ChatGPTError.self, from: data)
            throw error ?? ChatGPTServiceError.responseInvalid
        }

        let stream = AsyncThrowingStream<CompletionStreamDataChunk, Error> { continuation in
            let task = Task {
                do {
                    for try await line in result.lines {
                        if Task.isCancelled { break }
                        let prefix = "data: "
                        guard line.hasPrefix(prefix),
                              let content = line.dropFirst(prefix.count).data(using: .utf8),
                              let chunk = try? JSONDecoder()
                              .decode(CompletionStreamDataChunk.self, from: content)
                        else { continue }
                        continuation.yield(chunk)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in
                task.cancel()
                result.task.cancel()
            }
        }

        return stream
    }
}

