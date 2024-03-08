import AIModel
import Foundation
import Preferences

public actor OllamaChatCompletionsService {
    var apiKey: String
    var endpoint: URL
    var requestBody: ChatCompletionsRequestBody
    var model: ChatModel

    public enum ResponseFormat: String {
        case none = ""
        case json
    }

    init(
        apiKey: String,
        model: ChatModel,
        endpoint: URL,
        requestBody: ChatCompletionsRequestBody
    ) {
        self.apiKey = apiKey
        self.endpoint = endpoint
        self.requestBody = requestBody
        self.model = model
    }
}

extension OllamaChatCompletionsService: ChatCompletionsAPI {
    func callAsFunction() async throws -> ChatCompletionResponseBody {
        let requestBody = ChatCompletionRequestBody(
            model: model.info.modelName,
            messages: requestBody.messages.map { message in
                .init(role: {
                    switch message.role {
                    case .assistant:
                        return .assistant
                    case .user:
                        return .user
                    case .system:
                        return .system
                    case .tool:
                        return .user
                    }
                }(), content: message.content)
            },
            stream: false,
            options: .init(
                temperature: requestBody.temperature,
                stop: requestBody.stop,
                num_predict: requestBody.maxTokens
            ),
            keep_alive: nil,
            format: nil
        )

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(requestBody)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let (result, response) = try await URLSession.shared.data(for: request)

        guard let response = response as? HTTPURLResponse else {
            throw CancellationError()
        }

        guard response.statusCode == 200 else {
            let text = String(data: result, encoding: .utf8)
            throw Error.otherError(text ?? "Unknown error")
        }

        let body = try JSONDecoder().decode(
            ChatCompletionResponseChunk.self,
            from: result
        )

        return .init(
            object: body.model,
            model: body.model,
            message: body.message.map { message in
                .init(
                    role: {
                        switch message.role {
                        case .assistant:
                            return .assistant
                        case .user:
                            return .user
                        case .system:
                            return .system
                        }
                    }(),
                    content: message.content
                )
            } ?? .init(role: .assistant, content: ""),
            otherChoices: [],
            finishReason: ""
        )
    }
}

extension OllamaChatCompletionsService: ChatCompletionsStreamAPI {
    func callAsFunction() async throws
        -> AsyncThrowingStream<ChatCompletionsStreamDataChunk, Swift.Error>
    {
        let requestBody = ChatCompletionRequestBody(
            model: model.info.modelName,
            messages: requestBody.messages.map { message in
                .init(role: {
                    switch message.role {
                    case .assistant:
                        return .assistant
                    case .user:
                        return .user
                    case .system:
                        return .system
                    case .tool:
                        return .user
                    }
                }(), content: message.content)
            },
            stream: true,
            options: .init(
                temperature: requestBody.temperature,
                stop: requestBody.stop,
                num_predict: requestBody.maxTokens
            ),
            keep_alive: nil,
            format: nil
        )

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(requestBody)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let (result, response) = try await URLSession.shared.bytes(for: request)

        guard let response = response as? HTTPURLResponse else {
            throw CancellationError()
        }

        guard response.statusCode == 200 else {
            let text = try await result.lines.reduce(into: "") { partialResult, current in
                partialResult += current
            }
            throw Error.otherError(text)
        }

        let stream = ResponseStream(result: result) {
            let chunk = try JSONDecoder().decode(
                ChatCompletionResponseChunk.self,
                from: $0.data(using: .utf8) ?? Data()
            )
            return .init(chunk: chunk, done: chunk.done)
        }

        let sequence = stream.map { chunk in
            ChatCompletionsStreamDataChunk(
                id: UUID().uuidString,
                object: chunk.model,
                model: chunk.model,
                message: .init(
                    role: {
                        switch chunk.message?.role {
                        case .none:
                            return nil
                        case .assistant:
                            return .assistant
                        case .user:
                            return .user
                        case .system:
                            return .system
                        }
                    }(),
                    content: chunk.message?.content
                )
            )
        }

        return sequence.toStream()
    }
}

extension OllamaChatCompletionsService {
    struct Message: Codable, Equatable {
        public enum Role: String, Codable {
            case user
            case assistant
            case system
        }

        /// The role of the message.
        public var role: Role
        /// The content of the message.
        public var content: String
    }

    enum Error: Swift.Error, LocalizedError {
        case decodeError(Swift.Error)
        case otherError(String)

        public var errorDescription: String? {
            switch self {
            case let .decodeError(error):
                return error.localizedDescription
            case let .otherError(message):
                return message
            }
        }
    }
}

// MARK: - Chat Completion API

/// https://github.com/ollama/ollama/blob/main/docs/api.md#chat-request-streaming
extension OllamaChatCompletionsService {
    struct ChatCompletionRequestBody: Codable {
        struct Options: Codable {
            var temperature: Double?
            var stop: [String]?
            var num_predict: Int?
            var top_k: Int?
            var top_p: Double?
        }

        var model: String
        var messages: [Message]
        var stream: Bool
        var options: Options
        var keep_alive: String?
        var format: String?
    }

    struct ChatCompletionResponseChunk: Decodable {
        var model: String
        var message: Message?
        var response: String?
        var done: Bool
        var total_duration: Int64?
        var load_duration: Int64?
        var prompt_eval_count: Int?
        var prompt_eval_duration: Int64?
        var eval_count: Int?
        var eval_duration: Int64?
    }
}

