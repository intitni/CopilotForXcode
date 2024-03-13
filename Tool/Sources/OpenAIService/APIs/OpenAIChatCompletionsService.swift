import AIModel
import AsyncAlgorithms
import Foundation
import Logger
import Preferences

/// https://platform.openai.com/docs/api-reference/chat/create
actor OpenAIChatCompletionsService: ChatCompletionsStreamAPI, ChatCompletionsAPI {
    struct CompletionAPIError: Error, Decodable, LocalizedError {
        struct ErrorDetail: Decodable {
            var message: String
            var type: String?
            var param: String?
            var code: String?
        }

        struct MistralAIErrorMessage: Decodable {
            struct Detail: Decodable {
                var msg: String?
            }

            var message: String?
            var msg: String?
            var detail: [Detail]?
        }

        enum Message {
            case raw(String)
            case mistralAI(MistralAIErrorMessage)
        }

        var error: ErrorDetail?
        var message: Message

        var errorDescription: String? {
            if let message = error?.message { return message }
            switch message {
            case let .raw(string):
                return string
            case let .mistralAI(mistralAIErrorMessage):
                return mistralAIErrorMessage.message
                    ?? mistralAIErrorMessage.msg
                    ?? mistralAIErrorMessage.detail?.first?.msg
                    ?? "Unknown Error"
            }
        }

        enum CodingKeys: String, CodingKey {
            case error
            case message
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            do {
                error = try container.decode(ErrorDetail.self, forKey: .error)
            } catch {
                print(error)
                self.error = nil
            }
            message = {
                if let e = try? container.decode(MistralAIErrorMessage.self, forKey: .message) {
                    return CompletionAPIError.Message.mistralAI(e)
                }
                if let e = try? container.decode(String.self, forKey: .message) {
                    return .raw(e)
                }
                return .raw("Unknown Error")
            }()
        }
    }

    enum MessageRole: String, Codable {
        case system
        case user
        case assistant
        case function
        case tool

        var formalized: ChatCompletionsRequestBody.Message.Role {
            switch self {
            case .system: return .system
            case .user: return .user
            case .assistant: return .assistant
            case .function: return .tool
            case .tool: return .tool
            }
        }
    }

    struct StreamDataChunk: Codable {
        var id: String?
        var object: String?
        var model: String?
        var choices: [Choice]?

        struct Choice: Codable {
            var delta: Delta?
            var index: Int?
            var finish_reason: String?

            struct Delta: Codable {
                var role: MessageRole?
                var content: String?
                var function_call: RequestBody.MessageFunctionCall?
                var tool_calls: [RequestBody.MessageToolCall]?
            }
        }
    }

    struct ResponseBody: Codable, Equatable {
        struct Message: Codable, Equatable {
            /// The role of the message.
            var role: MessageRole
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
            var function_call: RequestBody.MessageFunctionCall?
            /// Tool calls in an assistant message.
            var tool_calls: [RequestBody.MessageToolCall]?
        }

        struct Choice: Codable, Equatable {
            var message: Message
            var index: Int?
            var finish_reason: String?
        }

        struct Usage: Codable, Equatable {
            var prompt_tokens: Int?
            var completion_tokens: Int?
            var total_tokens: Int?
        }

        var id: String?
        var object: String
        var model: String
        var usage: Usage
        var choices: [Choice]
    }

    struct RequestBody: Codable, Equatable {
        struct Message: Codable, Equatable {
            /// The role of the message.
            var role: MessageRole
            /// The content of the message.
            var content: String
            /// When we want to reply to a function call with the result, we have to provide the
            /// name of the function call, and include the result in `content`.
            ///
            /// - important: It's required when the role is `function`.
            var name: String?
            /// Tool calls in an assistant message.
            var tool_calls: [MessageToolCall]?
            /// When we want to call a tool, we have to provide the id of the call.
            ///
            /// - important: It's required when the role is `tool`.
            var tool_call_id: String?
            /// When the bot wants to call a function, it will reply with a function call.
            ///
            /// Deprecated.
            var function_call: MessageFunctionCall?
        }

        struct MessageFunctionCall: Codable, Equatable {
            /// The name of the
            var name: String?
            /// A JSON string.
            var arguments: String?
        }

        struct MessageToolCall: Codable, Equatable {
            /// When it's returned as a data chunk, use the index to identify the tool call.
            var index: Int?
            /// The id of the tool call.
            var id: String?
            /// The type of the tool.
            var type: String?
            /// The function call.
            var function: MessageFunctionCall?
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
        var max_tokens: Int?
        var tool_choice: FunctionCallStrategy?
        var tools: [Tool]?
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
        if !apiKey.isEmpty {
            switch model.format {
            case .openAI:
                if !model.info.openAIInfo.organizationID.isEmpty {
                    request.setValue(
                        "OpenAI-Organization",
                        forHTTPHeaderField: model.info.openAIInfo.organizationID
                    )
                }
                request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            case .openAICompatible:
                request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            case .azureOpenAI:
                request.setValue(apiKey, forHTTPHeaderField: "api-key")
            case .googleAI:
                assertionFailure("Unsupported")
            case .ollama:
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
            let error = try? decoder.decode(CompletionAPIError.self, from: data)
            throw error ?? ChatGPTServiceError.responseInvalid
        }

        let stream = ResponseStream<StreamDataChunk>(result: result) {
            var line = $0
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
                return .init(chunk: chunk, done: false)
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
        if !apiKey.isEmpty {
            switch model.format {
            case .openAI:
                if !model.info.openAIInfo.organizationID.isEmpty {
                    request.setValue(
                        "OpenAI-Organization",
                        forHTTPHeaderField: model.info.openAIInfo.organizationID
                    )
                }
                request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            case .openAICompatible:
                request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            case .azureOpenAI:
                request.setValue(apiKey, forHTTPHeaderField: "api-key")
            case .googleAI:
                assertionFailure("Unsupported")
            case .ollama:
                assertionFailure("Unsupported")
            }
        }

        let (result, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse else {
            throw ChatGPTServiceError.responseInvalid
        }

        guard response.statusCode == 200 else {
            let error = try? JSONDecoder().decode(CompletionAPIError.self, from: result)
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

extension OpenAIChatCompletionsService.ResponseBody {
    func formalized() -> ChatCompletionResponseBody {
        let message: ChatCompletionResponseBody.Message
        let otherMessages: [ChatCompletionResponseBody.Message]

        func convertMessage(_ message: Message) -> ChatCompletionResponseBody.Message {
            .init(
                role: message.role.formalized,
                content: message.content ?? "",
                toolCalls: {
                    if let toolCalls = message.tool_calls {
                        return toolCalls.map { toolCall in
                            .init(
                                id: toolCall.id ?? "",
                                type: toolCall.type ?? "function",
                                function: .init(
                                    name: toolCall.function?.name ?? "",
                                    arguments: toolCall.function?.arguments
                                )
                            )
                        }
                    } else if let functionCall = message.function_call {
                        return [
                            .init(
                                id: functionCall.name ?? "",
                                type: "function",
                                function: .init(
                                    name: functionCall.name ?? "",
                                    arguments: functionCall.arguments
                                )
                            ),
                        ]
                    } else {
                        return []
                    }
                }()
            )
        }

        if let first = choices.first?.message {
            message = convertMessage(first)
            otherMessages = choices.dropFirst().map { convertMessage($0.message) }
        } else {
            message = .init(role: .assistant, content: "")
            otherMessages = []
        }

        return .init(
            id: id,
            object: object,
            model: model,
            message: message,
            otherChoices: otherMessages,
            finishReason: choices.first?.finish_reason ?? ""
        )
    }
}

extension OpenAIChatCompletionsService.StreamDataChunk {
    func formalized() -> ChatCompletionsStreamDataChunk {
        .init(
            id: id,
            object: object,
            model: model,
            message: {
                if let choice = self.choices?.first {
                    return .init(
                        role: choice.delta?.role?.formalized,
                        content: choice.delta?.content,
                        toolCalls: {
                            if let toolCalls = choice.delta?.tool_calls {
                                return toolCalls.map {
                                    .init(
                                        index: $0.index,
                                        id: $0.id,
                                        type: $0.type,
                                        function: .init(
                                            name: $0.function?.name,
                                            arguments: $0.function?.arguments
                                        )
                                    )
                                }
                            }

                            if let functionCall = choice.delta?.function_call {
                                return [
                                    .init(
                                        index: 0,
                                        id: functionCall.name,
                                        type: "function",
                                        function: .init(
                                            name: functionCall.name,
                                            arguments: functionCall.arguments
                                        )
                                    ),
                                ]
                            }

                            return nil
                        }()
                    )
                }
                return nil
            }(),
            finishReason: choices?.first?.finish_reason
        )
    }
}

extension OpenAIChatCompletionsService.RequestBody {
    init(_ body: ChatCompletionsRequestBody) {
        model = body.model
        messages = body.messages.map { message in
            .init(
                role: {
                    switch message.role {
                    case .user:
                        return .user
                    case .assistant:
                        return .assistant
                    case .system:
                        return .system
                    case .tool:
                        return .tool
                    }
                }(),
                content: message.content,
                name: message.name,
                tool_calls: message.toolCalls?.map { tool in
                    MessageToolCall(
                        id: tool.id,
                        type: tool.type,
                        function: MessageFunctionCall(
                            name: tool.function.name,
                            arguments: tool.function.arguments
                        )
                    )
                },
                tool_call_id: message.toolCallId
            )
        }
        temperature = body.temperature
        stream = body.stream
        stop = body.stop
        max_tokens = body.maxTokens
        tool_choice = body.toolChoice
        tools = body.tools?.map {
            Tool(
                type: $0.type,
                function: $0.function
            )
        }
    }
}

