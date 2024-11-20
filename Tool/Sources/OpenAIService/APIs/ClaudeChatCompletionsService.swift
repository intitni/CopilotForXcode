import AIModel
import AsyncAlgorithms
import ChatBasic
import CodableWrappers
import Foundation
import Logger
import Preferences

/// https://docs.anthropic.com/claude/reference/messages_post
public actor ClaudeChatCompletionsService: ChatCompletionsStreamAPI, ChatCompletionsAPI {
    /// https://docs.anthropic.com/en/docs/about-claude/models
    public enum KnownModel: String, CaseIterable {
        case claude35Sonnet = "claude-3-5-sonnet-latest"
        case claude35Haiku = "claude-3-5-haiku-latest"
        case claude3Opus = "claude-3-opus-latest"
        case claude3Sonnet = "claude-3-sonnet-20240229"
        case claude3Haiku = "claude-3-haiku-20240307"

        public var contextWindow: Int {
            switch self {
            case .claude35Sonnet: return 200_000
            case .claude35Haiku: return 200_000
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
            error?.message ?? error?.type ?? type
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
        var usage: ResponseBody.Usage?

        struct Message: Decodable {
            var id: String
            var type: String
            var role: MessageRole?
            var content: [ContentBlock]?
            var model: String
            var stop_reason: String?
            var stop_sequence: String?
            var usage: ResponseBody.Usage?
        }

        struct ContentBlock: Decodable {
            var type: String
            var text: String?
        }

        struct Delta: Decodable {
            var type: String?
            var text: String?
            var stop_reason: String?
            var stop_sequence: String?
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
            var cache_creation_input_tokens: Int?
            var cache_read_input_tokens: Int?
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
        struct CacheControl: Encodable, Equatable {
            enum CacheControlType: String, Codable, Equatable {
                case ephemeral
            }

            var type: CacheControlType = .ephemeral
        }

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
            var cache_control: CacheControl?
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

        struct SystemPrompt: Encodable, Equatable {
            let type = "text"
            var text: String
            var cache_control: CacheControl?
        }

        struct Tool: Encodable, Equatable {
            var name: String
            var description: String
            var input_schema: JSONSchemaValue
        }

        var model: String
        var system: [SystemPrompt]
        var messages: [Message]
        var temperature: Double?
        var stream: Bool?
        var stop_sequences: [String]?
        var max_tokens: Int
        var tools: [RequestBody.Tool]?
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
        request.setValue("prompt-caching-2024-07-31", forHTTPHeaderField: "anthropic-beta")
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
                if let error = chunk.error {
                    throw error
                }
                return .init(chunk: chunk, done: chunk.type == "message_stop")
            } catch let error as APIError {
                Logger.service.error(error.errorDescription ?? "Unknown Error")
                throw error
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
        request.setValue("prompt-caching-2024-07-31", forHTTPHeaderField: "anthropic-beta")
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
            finishReason: stop_reason ?? "",
            usage: .init(
                promptTokens: usage.input_tokens ?? 0,
                completionTokens: usage.output_tokens ?? 0,
                cachedTokens: usage.cache_read_input_tokens ?? 0,
                otherUsage: {
                    var otherUsage = [String: Int]()
                    if let cacheCreation = usage.cache_creation_input_tokens {
                        otherUsage["cache_creation_input_tokens"] = cacheCreation
                    }
                    return otherUsage
                }()
            )
        )
    }
}

extension ClaudeChatCompletionsService.StreamDataChunk {
    func formalized() -> ChatCompletionsStreamDataChunk {
        let usage = usage ?? message?.usage
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
            finishReason: delta?.stop_reason,
            usage: .init(
                promptTokens: usage?.input_tokens,
                completionTokens: usage?.output_tokens,
                cachedTokens: usage?.cache_read_input_tokens,
                otherUsage: {
                    var otherUsage = [String: Int]()
                    if let cacheCreation = usage?.cache_creation_input_tokens {
                        otherUsage["cache_creation_input_tokens"] = cacheCreation
                    }
                    return otherUsage
                }()
            )
        )
    }
}

extension ClaudeChatCompletionsService.RequestBody {
    init(_ body: ChatCompletionsRequestBody) {
        model = body.model
        let supportsPromptCache = if model.hasPrefix("claude-3-5-sonnet") || model
            .hasPrefix("claude-3-opus") || model.hasPrefix("claude-3-haiku")
        {
            true
        } else {
            false
        }

        var systemPrompts = [SystemPrompt]()
        var nonSystemMessages = [Message]()

        enum JoinType {
            case joinMessage
            case appendToList
            case padMessageAndAppendToList
        }

        func checkJoinType(for message: ChatCompletionsRequestBody.Message) -> JoinType {
            guard let last = nonSystemMessages.last else { return .appendToList }
            let newMessageRole: ClaudeChatCompletionsService.MessageRole = message.role == .user
                ? .user
                : .assistant

            if newMessageRole != last.role {
                return .appendToList
            }

            if message.cacheIfPossible != last.content
                .contains(where: { $0.cache_control != nil })
            {
                return .padMessageAndAppendToList
            }

            return .joinMessage
        }

        /// Claude only supports caching at most 4 messages.
        var cacheControlMax = 4

        func consumeCacheControl() -> Bool {
            if cacheControlMax > 0 {
                cacheControlMax -= 1
                return true
            }
            return false
        }

        for message in body.messages {
            switch message.role {
            case .system:
                systemPrompts.append(.init(text: message.content, cache_control: {
                    if message.cacheIfPossible, supportsPromptCache, consumeCacheControl() {
                        return .init()
                    } else {
                        return nil
                    }
                }()))
            case .tool, .assistant:
                switch checkJoinType(for: message) {
                case .appendToList:
                    nonSystemMessages.append(.init(
                        role: .assistant,
                        content: [.init(type: .text, text: message.content)]
                    ))
                case .padMessageAndAppendToList, .joinMessage:
                    nonSystemMessages[nonSystemMessages.endIndex - 1].content.append(
                        .init(type: .text, text: message.content, cache_control: {
                            if message.cacheIfPossible, supportsPromptCache, consumeCacheControl() {
                                return .init()
                            } else {
                                return nil
                            }
                        }())
                    )
                }
            case .user:
                switch checkJoinType(for: message) {
                case .appendToList:
                    nonSystemMessages.append(.init(
                        role: .user,
                        content: [.init(type: .text, text: message.content)]
                    ))
                case .padMessageAndAppendToList, .joinMessage:
                    nonSystemMessages[nonSystemMessages.endIndex - 1].content.append(
                        .init(type: .text, text: message.content, cache_control: {
                            if message.cacheIfPossible, supportsPromptCache, consumeCacheControl() {
                                return .init()
                            } else {
                                return nil
                            }
                        }())
                    )
                }
            }
        }

        messages = nonSystemMessages
        system = systemPrompts
        temperature = body.temperature
        stream = body.stream
        stop_sequences = body.stop
        max_tokens = body.maxTokens ?? 4000
    }
}

