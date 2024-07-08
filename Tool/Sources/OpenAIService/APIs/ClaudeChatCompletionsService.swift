import AIModel
import AsyncAlgorithms
import CodableWrappers
import Foundation
import Logger
import Preferences

/// https://docs.anthropic.com/claude/reference/messages_post
public actor ClaudeChatCompletionsService: ChatCompletionsStreamAPI, ChatCompletionsAPI {
    public enum KnownModel: String, CaseIterable {
        case claude35Sonnet = "claude-3-5-sonnet-20240620"
        case claude3Opus = "claude-3-opus-20240229"
        case claude3Sonnet = "claude-3-sonnet-20240229"
        case claude3Haiku = "claude-3-haiku-20240307"

        public var contextWindow: Int {
            switch self {
            case .claude35Sonnet: return 200_000
            case .claude3Opus: return 200_000
            case .claude3Sonnet: return 200_000
            case .claude3Haiku: return 200_000
            }
        }
    }

    struct APIError: Error, Decodable, LocalizedError {
        struct ErrorDetail: Decodable {
            var message: String?
            var type: String?
        }

        var error: ErrorDetail?
        var type: String

        var errorDescription: String? {
            error?.message ?? "Unknown Error"
        }
    }

    enum MessageRole: String, Codable {
        case user
        case assistant

        var formalized: ChatCompletionsRequestBody.Message.Role {
            switch self {
            case .user: return .user
            case .assistant: return .assistant
            }
        }
    }

    struct StreamDataChunk: Decodable {
        var type: String
        var message: Message?
        var index: Int?
        var content_block: ContentBlock?
        var delta: Delta?
        var error: APIError?

        struct Message: Decodable {
            var id: String
            var type: String
            var role: MessageRole?
            var content: [ContentBlock]?
            var model: String
            var stop_reason: String?
            var stop_sequence: String?
            var usage: Usage?
        }

        struct ContentBlock: Decodable {
            var type: String
            var text: String?
        }

        struct Delta: Decodable {
            var type: String
            var text: String?
            var stop_reason: String?
            var stop_sequence: String?
            var usage: Usage?
        }

        struct Usage: Decodable {
            var input_tokens: Int?
            var output_tokens: Int?
        }
    }

    struct ResponseBody: Codable, Equatable {
        struct Content: Codable, Equatable {
            enum ContentType: String, Codable, FallbackValueProvider {
                case text
                case unknown
                static var defaultValue: ContentType { .unknown }
            }

            /// The type of the message.
            ///
            /// Currently, the only supported type is `text`.
            @FallbackDecoding<ContentType>
            var type: ContentType
            /// The content of the message.
            ///
            /// If the request input messages ended with an assistant turn,
            /// then the response content will continue directly from that last turn.
            /// You can use this to constrain the model's output.
            var text: String?
        }

        struct Usage: Codable, Equatable {
            var input_tokens: Int?
            var output_tokens: Int?
        }

        var id: String?
        var model: String
        var type: String
        var usage: Usage
        var role: MessageRole
        var content: [Content]
        var stop_reason: String?
        var stop_sequence: String?
    }

    struct RequestBody: Encodable, Equatable {
        struct MessageContent: Encodable, Equatable {
            enum MessageContentType: String, Encodable, Equatable {
                case text
                case image
            }

            struct ImageSource: Encodable, Equatable {
                var type: String = "base64"
                /// currently support the base64 source type for images,
                /// and the image/jpeg, image/png, image/gif, and image/webp media types.
                var media_type: String = "image/jpeg"
                var data: String
            }

            var type: MessageContentType
            var text: String?
            var source: ImageSource?
        }

        struct Message: Encodable, Equatable {
            /// The role of the message.
            var role: MessageRole
            /// The content of the message.
            var content: [MessageContent]

            mutating func appendText(_ text: String) {
                var otherContents = [MessageContent]()
                var existedText = ""
                for existed in content {
                    switch existed.type {
                    case .text:
                        if existedText.isEmpty {
                            existedText = existed.text ?? ""
                        } else if let text = existed.text {
                            existedText += "\n\n" + text
                        }
                    default:
                        otherContents.append(existed)
                    }
                }

                content = otherContents + [.init(type: .text, text: existedText + "\n\n\(text)")]
            }
        }

        var model: String
        var system: String
        var messages: [Message]
        var temperature: Double?
        var stream: Bool?
        var stop_sequences: [String]?
        var max_tokens: Int
    }

    var apiKey: String
    var endpoint: URL
    var requestBody: RequestBody
    var model: ChatModel

    init(
        apiKey: String,
        model: ChatModel,
        endpoint: URL,
        requestBody: ChatCompletionsRequestBody
    ) {
        self.apiKey = apiKey
        self.endpoint = endpoint
        self.requestBody = .init(requestBody)
        self.model = model
    }

    func callAsFunction() async throws
        -> AsyncThrowingStream<ChatCompletionsStreamDataChunk, Error>
    {
        requestBody.stream = true
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(requestBody)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        if !apiKey.isEmpty {
            request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
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
            let error = try? decoder.decode(APIError.self, from: data)
            throw error ?? ChatGPTServiceError.responseInvalid
        }

        let stream = ResponseStream<StreamDataChunk>(result: result) {
            var line = $0
            if line.hasPrefix("event:") {
                return .init(chunk: nil, done: false)
            }

            let prefix = "data: "
            if line.hasPrefix(prefix) {
                line.removeFirst(prefix.count)
            }

            if line == "[DONE]" { return .init(chunk: nil, done: true) }

            do {
                let chunk = try JSONDecoder().decode(
                    StreamDataChunk.self,
                    from: line.data(using: .utf8) ?? Data()
                )
                return .init(chunk: chunk, done: chunk.type == "message_stop")
            } catch {
                Logger.service.error("Error decoding stream data: \(error)")
                return .init(chunk: nil, done: false)
            }
        }

        return stream.map { $0.formalized() }.toStream()
    }

    func callAsFunction() async throws -> ChatCompletionResponseBody {
        requestBody.stream = false
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(requestBody)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        if !apiKey.isEmpty {
            request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        }

        let (result, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse else {
            throw ChatGPTServiceError.responseInvalid
        }

        guard response.statusCode == 200 else {
            let error = try? JSONDecoder().decode(APIError.self, from: result)
            throw error ?? ChatGPTServiceError
                .otherError(String(data: result, encoding: .utf8) ?? "Unknown Error")
        }

        do {
            let body = try JSONDecoder().decode(ResponseBody.self, from: result)
            return body.formalized()
        } catch {
            dump(error)
            throw error
        }
    }
}

extension ClaudeChatCompletionsService.ResponseBody {
    func formalized() -> ChatCompletionResponseBody {
        return .init(
            id: id,
            object: "chat.completions",
            model: model,
            message: .init(
                role: role.formalized,
                content: content.reduce(into: "") { partialResult, next in
                    if let text = next.text {
                        partialResult += text
                    }
                }
            ),
            otherChoices: [],
            finishReason: stop_reason ?? ""
        )
    }
}

extension ClaudeChatCompletionsService.StreamDataChunk {
    func formalized() -> ChatCompletionsStreamDataChunk {
        return .init(
            id: message?.id,
            object: "chat.completions",
            model: message?.model,
            message: {
                if let delta {
                    return .init(content: delta.text)
                }
                if let message {
                    return .init(role: message.role?.formalized)
                }
                return nil
            }(),
            finishReason: delta?.stop_reason
        )
    }
}

extension ClaudeChatCompletionsService.RequestBody {
    init(_ body: ChatCompletionsRequestBody) {
        model = body.model

        var systemPrompts = [String]()
        var nonSystemMessages = [Message]()

        for message in body.messages {
            switch message.role {
            case .system:
                systemPrompts.append(message.content)
            case .tool, .assistant:
                if let last = nonSystemMessages.last, last.role == .assistant {
                    nonSystemMessages[nonSystemMessages.endIndex - 1].appendText(message.content)
                } else {
                    nonSystemMessages.append(.init(
                        role: .assistant,
                        content: [.init(type: .text, text: message.content)]
                    ))
                }
            case .user:
                if let last = nonSystemMessages.last, last.role == .user {
                    nonSystemMessages[nonSystemMessages.endIndex - 1].appendText(message.content)
                } else {
                    nonSystemMessages.append(.init(
                        role: .user,
                        content: [.init(type: .text, text: message.content)]
                    ))
                }
            }
        }

        messages = nonSystemMessages
        system = systemPrompts.joined(separator: "\n\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        temperature = body.temperature
        stream = body.stream
        stop_sequences = body.stop
        max_tokens = body.maxTokens ?? 4000
    }
}

