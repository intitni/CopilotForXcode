import AIModel
import AsyncAlgorithms
import ChatBasic
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

            error = try container.decode(ErrorDetail.self, forKey: .error)
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
        var usage: ResponseBody.Usage?

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
            var prompt_tokens_details: PromptTokensDetails?
            var completion_tokens_details: CompletionTokensDetails?

            struct PromptTokensDetails: Codable, Equatable {
                var cached_tokens: Int?
                var audio_tokens: Int?
            }

            struct CompletionTokensDetails: Codable, Equatable {
                var reasoning_tokens: Int?
                var audio_tokens: Int?
            }
        }

        var id: String?
        var object: String
        var model: String
        var usage: Usage
        var choices: [Choice]
    }

    struct RequestBody: Encodable, Equatable {
        typealias ClaudeCacheControl = ClaudeChatCompletionsService.RequestBody.CacheControl

        struct Message: Encodable, Equatable {
            enum MessageContent: Encodable, Equatable {
                struct TextContentPart: Encodable, Equatable {
                    var type = "text"
                    var text: String
                    var cache_control: ClaudeCacheControl?
                }

                struct ImageContentPart: Encodable, Equatable {
                    struct ImageURL: Encodable, Equatable {
                        var url: String
                        var detail: String?
                    }

                    var type = "image_url"
                    var image_url: ImageURL
                }

                struct AudioContentPart: Encodable, Equatable {
                    struct InputAudio: Encodable, Equatable {
                        var data: String
                        var format: String
                    }

                    var type = "input_audio"
                    var input_audio: InputAudio
                }

                enum ContentPart: Encodable, Equatable {
                    case text(TextContentPart)
                    case image(ImageContentPart)
                    case audio(AudioContentPart)

                    func encode(to encoder: any Encoder) throws {
                        var container = encoder.singleValueContainer()
                        switch self {
                        case let .text(text):
                            try container.encode(text)
                        case let .image(image):
                            try container.encode(image)
                        case let .audio(audio):
                            try container.encode(audio)
                        }
                    }
                }

                case contentParts([ContentPart])
                case text(String)

                func encode(to encoder: any Encoder) throws {
                    var container = encoder.singleValueContainer()
                    switch self {
                    case let .contentParts(parts):
                        try container.encode(parts)
                    case let .text(text):
                        try container.encode(text)
                    }
                }
            }

            /// The role of the message.
            var role: MessageRole
            /// The content of the message.
            var content: MessageContent
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

        struct Tool: Encodable, Equatable {
            var type: String = "function"
            var function: ChatGPTFunctionSchema
        }

        struct StreamOptions: Encodable, Equatable {
            var include_usage: Bool = true
        }

        var model: String
        var messages: [Message]
        var temperature: Double?
        var stream: Bool?
        var stop: [String]?
        var max_completion_tokens: Int?
        var tool_choice: FunctionCallStrategy?
        var tools: [Tool]?
        var stream_options: StreamOptions?
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
        self.requestBody = .init(
            requestBody,
            endpoint: endpoint,
            enforceMessageOrder: model.info.openAICompatibleInfo.enforceMessageOrder,
            canUseTool: model.info.supportsFunctionCalling,
            supportsImage: model.info.supportsImage,
            supportsAudio: model.info.supportsAudio
        )
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

        Self.setupAppInformation(&request)
        Self.setupAPIKey(&request, model: model, apiKey: apiKey)
        Self.setupExtraHeaderFields(&request, model: model)

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
            if response.statusCode == 403 {
                throw ChatGPTServiceError.unauthorized(text)
            }
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
        let stream: AsyncThrowingStream<ChatCompletionsStreamDataChunk, Error> =
            try await callAsFunction()

        var body = ChatCompletionResponseBody(
            id: nil,
            object: "",
            model: "",
            message: .init(role: .assistant, content: ""),
            otherChoices: [],
            finishReason: "",
            usage: .init(
                promptTokens: 0,
                completionTokens: 0,
                cachedTokens: 0,
                otherUsage: [:]
            )
        )
        for try await chunk in stream {
            if let id = chunk.id {
                body.id = id
            }
            if let finishReason = chunk.finishReason {
                body.finishReason = finishReason
            }
            if let model = chunk.model {
                body.model = model
            }
            if let object = chunk.object {
                body.object = object
            }
            if let role = chunk.message?.role {
                body.message.role = role
            }
            if let text = chunk.message?.content {
                let existed = body.message.content ?? ""
                body.message.content = existed + text
            }
            if let usage = chunk.usage {
                body.usage?.merge(with: usage)
            }
        }
        return body
    }

    static func setupAppInformation(_ request: inout URLRequest) {
        if #available(macOS 13.0, *) {
            if request.url?.host == "openrouter.ai" {
                request.setValue("Copilot for Xcode", forHTTPHeaderField: "X-Title")
                request.setValue(
                    "https://github.com/intitni/CopilotForXcode",
                    forHTTPHeaderField: "HTTP-Referer"
                )
            }
        } else {
            if request.url?.host == "openrouter.ai" {
                request.setValue("Copilot for Xcode", forHTTPHeaderField: "X-Title")
                request.setValue(
                    "https://github.com/intitni/CopilotForXcode",
                    forHTTPHeaderField: "HTTP-Referer"
                )
            }
        }
    }

    static func setupAPIKey(_ request: inout URLRequest, model: ChatModel, apiKey: String) {
        if !apiKey.isEmpty {
            switch model.format {
            case .openAI:
                if !model.info.openAIInfo.organizationID.isEmpty {
                    request.setValue(
                        model.info.openAIInfo.organizationID,
                        forHTTPHeaderField: "OpenAI-Organization"
                    )
                }

                if !model.info.openAIInfo.projectID.isEmpty {
                    request.setValue(
                        model.info.openAIInfo.projectID,
                        forHTTPHeaderField: "OpenAI-Project"
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
            case .claude:
                assertionFailure("Unsupported")
            }
        }
    }

    static func setupExtraHeaderFields(_ request: inout URLRequest, model: ChatModel) {
        for field in model.info.customHeaderInfo.headers where !field.key.isEmpty {
            request.setValue(field.value, forHTTPHeaderField: field.key)
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
                        return nil
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

        let usage = ChatCompletionResponseBody.Usage(
            promptTokens: usage.prompt_tokens ?? 0,
            completionTokens: usage.completion_tokens ?? 0,
            cachedTokens: usage.prompt_tokens_details?.cached_tokens ?? 0,
            otherUsage: [
                "audio_tokens": usage.completion_tokens_details?.audio_tokens ?? 0,
                "reasoning_tokens": usage.completion_tokens_details?.reasoning_tokens ?? 0,
            ]
        )

        return .init(
            id: id,
            object: object,
            model: model,
            message: message,
            otherChoices: otherMessages,
            finishReason: choices.first?.finish_reason ?? "",
            usage: usage
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
            finishReason: choices?.first?.finish_reason,
            usage: .init(
                promptTokens: usage?.prompt_tokens,
                completionTokens: usage?.completion_tokens,
                cachedTokens: usage?.prompt_tokens_details?.cached_tokens,
                otherUsage: {
                    var dict = [String: Int]()
                    if let audioTokens = usage?.completion_tokens_details?.audio_tokens {
                        dict["audio_tokens"] = audioTokens
                    }
                    if let reasoningTokens = usage?.completion_tokens_details?.reasoning_tokens {
                        dict["reasoning_tokens"] = reasoningTokens
                    }
                    return dict
                }()
            )
        )
    }
}

extension OpenAIChatCompletionsService.RequestBody {
    static func convertContentPart(
        content: String,
        images: [ChatCompletionsRequestBody.Message.Image],
        audios: [ChatCompletionsRequestBody.Message.Audio]
    ) -> [Message.MessageContent.ContentPart] {
        var all = [Message.MessageContent.ContentPart]()
        all.append(.text(.init(text: content)))

        for image in images {
            all.append(.image(.init(
                image_url: .init(
                    url: image.dataURLString,
                    detail: nil
                )
            )))
        }

        for audio in audios {
            all.append(.audio(.init(
                input_audio: .init(
                    data: audio.data.base64EncodedString(),
                    format: audio.format.rawValue
                )
            )))
        }

        return all
    }

    static func convertContentPart(
        _ part: ClaudeChatCompletionsService.RequestBody.MessageContent
    ) -> Message.MessageContent.ContentPart? {
        switch part.type {
        case .text:
            return .text(.init(text: part.text ?? "", cache_control: part.cache_control))
        case .image:
            let type = part.source?.type ?? "base64"
            let base64Data = part.source?.data ?? ""
            let mediaType = part.source?.media_type ?? "image/png"
            return .image(.init(image_url: .init(url: "data:\(mediaType);\(type),\(base64Data)")))
        }
    }

    static func joinMessageContent(
        _ message: inout Message,
        content: String,
        images: [ChatCompletionsRequestBody.Message.Image],
        audios: [ChatCompletionsRequestBody.Message.Audio]
    ) {
        switch message.role {
        case .system, .assistant, .user:
            let newParts = Self.convertContentPart(
                content: content,
                images: images,
                audios: audios
            )
            if case let .contentParts(existingParts) = message.content {
                message.content = .contentParts(existingParts + newParts)
            } else {
                message.content = .contentParts(newParts)
            }
        case .tool, .function:
            if case let .text(existingText) = message.content {
                message.content = .text(existingText + "\n\n" + content)
            } else {
                message.content = .text(content)
            }
        }
    }

    init(
        _ body: ChatCompletionsRequestBody,
        endpoint: URL,
        enforceMessageOrder: Bool,
        canUseTool: Bool,
        supportsImage: Bool,
        supportsAudio: Bool
    ) {
        temperature = body.temperature
        stream = body.stream
        stop = body.stop
        max_completion_tokens = body.maxTokens
        tool_choice = body.toolChoice
        tools = body.tools?.map {
            Tool(
                type: $0.type,
                function: $0.function
            )
        }
        stream_options = if body.stream ?? false {
            StreamOptions()
        } else {
            nil
        }

        model = body.model

        // Special case for Claude through OpenRouter
        
        if endpoint.absoluteString.contains("openrouter.ai"), model.hasPrefix("anthropic/") {
            var body = body
            body.model = model.replacingOccurrences(of: "anthropic/", with: "")
            let claudeRequestBody = ClaudeChatCompletionsService.RequestBody(body)
            messages = claudeRequestBody.system.map {
                Message(
                    role: .system,
                    content: .contentParts([.text(.init(
                        text: $0.text,
                        cache_control: $0.cache_control
                    ))])
                )
            } + claudeRequestBody.messages.map {
                (message: ClaudeChatCompletionsService.RequestBody.Message) in
                let role: OpenAIChatCompletionsService.MessageRole = switch message.role {
                case .user: .user
                case .assistant: .assistant
                }
                return Message(
                    role: role,
                    content: .contentParts(message.content.compactMap(Self.convertContentPart)),
                    name: nil,
                    tool_calls: nil,
                    tool_call_id: nil
                )
            }
            return
        }
        
        // Enforce message order

        if enforceMessageOrder {
            var systemPrompts = [Message.MessageContent.ContentPart]()
            var nonSystemMessages = [Message]()

            for message in body.messages {
                switch (message.role, canUseTool) {
                case (.system, _):
                    systemPrompts.append(contentsOf: Self.convertContentPart(
                        content: message.content,
                        images: supportsImage ? message.images : [],
                        audios: supportsAudio ? message.audios : []
                    ))
                case (.tool, true):
                    if let last = nonSystemMessages.last, last.role == .tool {
                        Self.joinMessageContent(
                            &nonSystemMessages[nonSystemMessages.endIndex - 1],
                            content: message.content,
                            images: supportsImage ? message.images : [],
                            audios: supportsAudio ? message.audios : []
                        )
                    } else {
                        nonSystemMessages.append(.init(
                            role: .tool,
                            content: .contentParts(Self.convertContentPart(
                                content: message.content,
                                images: supportsImage ? message.images : [],
                                audios: supportsAudio ? message.audios : []
                            )),
                            tool_calls: message.toolCalls?.map { tool in
                                MessageToolCall(
                                    id: tool.id,
                                    type: tool.type,
                                    function: MessageFunctionCall(
                                        name: tool.function.name,
                                        arguments: tool.function.arguments
                                    )
                                )
                            }
                        ))
                    }
                case (.assistant, _), (.tool, false):
                    if let last = nonSystemMessages.last, last.role == .assistant {
                        Self.joinMessageContent(
                            &nonSystemMessages[nonSystemMessages.endIndex - 1],
                            content: message.content,
                            images: supportsImage ? message.images : [],
                            audios: supportsAudio ? message.audios : []
                        )
                    } else {
                        nonSystemMessages.append(.init(
                            role: .assistant,
                            content: .contentParts(Self.convertContentPart(
                                content: message.content,
                                images: supportsImage ? message.images : [],
                                audios: supportsAudio ? message.audios : []
                            ))
                        ))
                    }
                case (.user, _):
                    if let last = nonSystemMessages.last, last.role == .user {
                        Self.joinMessageContent(
                            &nonSystemMessages[nonSystemMessages.endIndex - 1],
                            content: message.content,
                            images: supportsImage ? message.images : [],
                            audios: supportsAudio ? message.audios : []
                        )
                    } else {
                        nonSystemMessages.append(.init(
                            role: .user,
                            content: .contentParts(Self.convertContentPart(
                                content: message.content,
                                images: supportsImage ? message.images : [],
                                audios: supportsAudio ? message.audios : []
                            )),
                            name: message.name,
                            tool_call_id: message.toolCallId
                        ))
                    }
                }
            }
            messages = [
                .init(
                    role: .system,
                    content: .contentParts(systemPrompts)
                ),
            ] + nonSystemMessages

            return
        }
        
        // Default
        
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
                content: .contentParts(Self.convertContentPart(
                    content: message.content,
                    images: supportsImage ? message.images : [],
                    audios: supportsAudio ? message.audios : []
                )),
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
    }
}

