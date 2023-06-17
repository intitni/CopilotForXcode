import AsyncAlgorithms
import Foundation
import Preferences
import JSONRPC

typealias CompletionStreamAPIBuilder = (String, ChatFeatureProvider, URL, CompletionRequestBody) -> CompletionStreamAPI

protocol CompletionStreamAPI {
    func callAsFunction() async throws -> (
        trunkStream: AsyncThrowingStream<CompletionStreamDataTrunk, Error>,
        cancel: Cancellable
    )
}

/// https://platform.openai.com/docs/api-reference/chat/create
struct CompletionRequestBody: Encodable, Equatable {
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
        var function_call: MessageFunctionCall?
    }
    
    struct MessageFunctionCall: Codable, Equatable {
        /// The name of the
        var name: String
        /// A JSON string.
        var arguments: String
    }
    
    enum FunctionCallStrategy: Encodable, Equatable {
        /// Forbid the bot to call any function.
        case none
        /// Let the bot choose what function to call.
        case auto
        /// Force the bot to call a function with the given name.
        case name(String)
        
        struct CallFunctionNamed: Codable {
            var name: String
        }

        func encode(to encoder: Encoder) throws {
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
    var function_call: FunctionCallStrategy?
    var functions: [Int] = []
}

struct CompletionStreamDataTrunk: Codable {
    var id: String
    var object: String
    var created: Int
    var model: String
    var choices: [Choice]

    struct Choice: Codable {
        var delta: Delta
        var index: Int
        var finish_reason: String?

        struct Delta: Codable {
            var role: ChatMessage.Role?
            var content: String?
            var function_call: String?
        }
    }
}

struct OpenAICompletionStreamAPI: CompletionStreamAPI {
    var apiKey: String
    var endpoint: URL
    var requestBody: CompletionRequestBody
    var provider: ChatFeatureProvider

    init(
        apiKey: String,
        provider: ChatFeatureProvider,
        endpoint: URL,
        requestBody: CompletionRequestBody
    ) {
        self.apiKey = apiKey
        self.endpoint = endpoint
        self.requestBody = requestBody
        self.requestBody.stream = true
        self.provider = provider
    }

    func callAsFunction() async throws -> (
        trunkStream: AsyncThrowingStream<CompletionStreamDataTrunk, Error>,
        cancel: Cancellable
    ) {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(requestBody)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !apiKey.isEmpty {
            if provider == .openAI {
                request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            } else {
                request.setValue(apiKey, forHTTPHeaderField: "api-key")
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

        var receivingDataTask: Task<Void, Error>?

        let stream = AsyncThrowingStream<CompletionStreamDataTrunk, Error> { continuation in
            receivingDataTask = Task {
                do {
                    for try await line in result.lines {
                        if Task.isCancelled { break }
                        let prefix = "data: "
                        guard line.hasPrefix(prefix),
                              let content = line.dropFirst(prefix.count).data(using: .utf8),
                              let trunk = try? JSONDecoder()
                              .decode(CompletionStreamDataTrunk.self, from: content)
                        else { continue }
                        continuation.yield(trunk)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }

        return (
            stream,
            Cancellable {
                result.task.cancel()
                receivingDataTask?.cancel()
            }
        )
    }
}

