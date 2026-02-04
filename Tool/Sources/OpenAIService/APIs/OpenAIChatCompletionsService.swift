import AIModel
import AsyncAlgorithms
import ChatBasic
import Foundation
import JoinJSON
import Logger
import Preferences

/// https://platform.openai.com/docs/api-reference/chat/create
public actor OpenAIChatCompletionsService: ChatCompletionsStreamAPI, ChatCompletionsAPI {
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

    public enum MessageRole: String, Codable, Sendable {
        case system
        case user
        case assistant
        case function
        case tool
        case developer

        var formalized: ChatCompletionsRequestBody.Message.Role {
            switch self {
            case .system: return .system
            case .developer: return .system
            case .user: return .user
            case .assistant: return .assistant
            case .function: return .tool
            case .tool: return .tool
            }
        }
    }

    public struct StreamDataChunk: Codable, Sendable {
        public var id: String?
        public var provider: String?
        public var object: String?
        public var model: String?
        public var choices: [Choice]?
        public var usage: ResponseBody.Usage?
        public var created: Int?

        public struct Choice: Codable, Sendable {
            public var delta: Delta?
            public var index: Int?
            public var finish_reason: String?

            public struct Delta: Codable, Sendable {
                public var role: MessageRole?
                public var content: String?
                public var reasoning_content: String?
                public var reasoning: String?
                public var function_call: RequestBody.MessageFunctionCall?
                public var tool_calls: [RequestBody.MessageToolCall]?

                public init(
                    role: MessageRole? = nil,
                    content: String? = nil,
                    reasoning_content: String? = nil,
                    reasoning: String? = nil,
                    function_call: RequestBody.MessageFunctionCall? = nil,
                    tool_calls: [RequestBody.MessageToolCall]? = nil
                ) {
                    self.role = role
                    self.content = content
                    self.reasoning_content = reasoning_content
                    self.reasoning = reasoning
                    self.function_call = function_call
                    self.tool_calls = tool_calls
                }
            }

            public init(delta: Delta? = nil, index: Int? = nil, finish_reason: String? = nil) {
                self.delta = delta
                self.index = index
                self.finish_reason = finish_reason
            }
        }

        public init(
            id: String? = nil,
            provider: String? = nil,
            object: String? = nil,
            model: String? = nil,
            choices: [Choice]? = nil,
            usage: ResponseBody.Usage? = nil,
            created: Int? = nil
        ) {
            self.id = id
            self.provider = provider
            self.object = object
            self.model = model
            self.choices = choices
            self.usage = usage
            self.created = created
        }
    }

    public struct ResponseBody: Codable, Equatable {
        public struct Message: Codable, Equatable, Sendable {
            /// The role of the message.
            public var role: MessageRole
            /// The content of the message.
            public var content: String?
            public var reasoning_content: String?
            public var reasoning: String?
            /// When we want to reply to a function call with the result, we have to provide the
            /// name of the function call, and include the result in `content`.
            ///
            /// - important: It's required when the role is `function`.
            public var name: String?
            /// When the bot wants to call a function, it will reply with a function call in format:
            /// ```json
            /// {
            ///   "name": "weather",
            ///   "arguments": "{ \"location\": \"earth\" }"
            /// }
            /// ```
            public var function_call: RequestBody.MessageFunctionCall?
            /// Tool calls in an assistant message.
            public var tool_calls: [RequestBody.MessageToolCall]?

            public init(
                role: MessageRole,
                content: String? = nil,
                reasoning_content: String? = nil,
                reasoning: String? = nil,
                name: String? = nil,
                function_call: RequestBody.MessageFunctionCall? = nil,
                tool_calls: [RequestBody.MessageToolCall]? = nil
            ) {
                self.role = role
                self.content = content
                self.reasoning_content = reasoning_content
                self.reasoning = reasoning
                self.name = name
                self.function_call = function_call
                self.tool_calls = tool_calls
            }
        }

        public struct Choice: Codable, Equatable, Sendable {
            public var message: Message
            public var index: Int?
            public var finish_reason: String?

            public init(message: Message, index: Int? = nil, finish_reason: String? = nil) {
                self.message = message
                self.index = index
                self.finish_reason = finish_reason
            }
        }

        public struct Usage: Codable, Equatable, Sendable {
            public var prompt_tokens: Int?
            public var completion_tokens: Int?
            public var total_tokens: Int?
            public var prompt_tokens_details: PromptTokensDetails?
            public var completion_tokens_details: CompletionTokensDetails?

            public struct PromptTokensDetails: Codable, Equatable, Sendable {
                public var cached_tokens: Int?
                public var audio_tokens: Int?

                public init(cached_tokens: Int? = nil, audio_tokens: Int? = nil) {
                    self.cached_tokens = cached_tokens
                    self.audio_tokens = audio_tokens
                }
            }

            public struct CompletionTokensDetails: Codable, Equatable, Sendable {
                public var reasoning_tokens: Int?
                public var audio_tokens: Int?

                public init(reasoning_tokens: Int? = nil, audio_tokens: Int? = nil) {
                    self.reasoning_tokens = reasoning_tokens
                    self.audio_tokens = audio_tokens
                }
            }

            public init(
                prompt_tokens: Int? = nil,
                completion_tokens: Int? = nil,
                total_tokens: Int? = nil,
                prompt_tokens_details: PromptTokensDetails? = nil,
                completion_tokens_details: CompletionTokensDetails? = nil
            ) {
                self.prompt_tokens = prompt_tokens
                self.completion_tokens = completion_tokens
                self.total_tokens = total_tokens
                self.prompt_tokens_details = prompt_tokens_details
                self.completion_tokens_details = completion_tokens_details
            }
        }

        public var id: String?
        public var object: String
        public var model: String
        public var usage: Usage
        public var choices: [Choice]

        public init(
            id: String? = nil,
            object: String,
            model: String,
            usage: Usage,
            choices: [Choice]
        ) {
            self.id = id
            self.object = object
            self.model = model
            self.usage = usage
            self.choices = choices
        }
    }

    public struct RequestBody: Codable, Equatable {
        public typealias ClaudeCacheControl = ClaudeChatCompletionsService.RequestBody.CacheControl

        public struct GitHubCopilotCacheControl: Codable, Equatable, Sendable {
            public var type: String

            public init(type: String = "ephemeral") {
                self.type = type
            }
        }

        public struct Message: Codable, Equatable {
            public enum MessageContent: Codable, Equatable {
                public struct TextContentPart: Codable, Equatable {
                    public var type = "text"
                    public var text: String
                    public var cache_control: ClaudeCacheControl?

                    public init(
                        type: String = "text",
                        text: String,
                        cache_control: ClaudeCacheControl? = nil
                    ) {
                        self.type = type
                        self.text = text
                        self.cache_control = cache_control
                    }
                }

                public struct ImageContentPart: Codable, Equatable {
                    public struct ImageURL: Codable, Equatable {
                        public var url: String
                        public var detail: String?

                        public init(url: String, detail: String? = nil) {
                            self.url = url
                            self.detail = detail
                        }
                    }

                    public var type = "image_url"
                    public var image_url: ImageURL

                    public init(type: String = "image_url", image_url: ImageURL) {
                        self.type = type
                        self.image_url = image_url
                    }
                }

                public struct AudioContentPart: Codable, Equatable {
                    public struct InputAudio: Codable, Equatable {
                        public var data: String
                        public var format: String

                        public init(data: String, format: String) {
                            self.data = data
                            self.format = format
                        }
                    }

                    public var type = "input_audio"
                    public var input_audio: InputAudio

                    public init(type: String = "input_audio", input_audio: InputAudio) {
                        self.type = type
                        self.input_audio = input_audio
                    }
                }

                public enum ContentPart: Codable, Equatable {
                    case text(TextContentPart)
                    case image(ImageContentPart)
                    case audio(AudioContentPart)

                    public func encode(to encoder: any Encoder) throws {
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

                    public init(from decoder: any Decoder) throws {
                        let container = try decoder.singleValueContainer()
                        var errors: [Error] = []

                        do {
                            let text = try container.decode(String.self)
                            self = .text(.init(text: text))
                            return
                        } catch {
                            errors.append(error)
                        }

                        do {
                            let text = try container.decode(TextContentPart.self)
                            self = .text(text)
                            return
                        } catch {
                            errors.append(error)
                        }

                        do {
                            let image = try container.decode(ImageContentPart.self)
                            self = .image(image)
                            return
                        } catch {
                            errors.append(error)
                        }

                        do {
                            let audio = try container.decode(AudioContentPart.self)
                            self = .audio(audio)
                            return
                        } catch {
                            errors.append(error)
                        }

                        struct E: Error, LocalizedError {
                            let errors: [Error]

                            var errorDescription: String? {
                                "Failed to decode ContentPart: \(errors.map { $0.localizedDescription }.joined(separator: "; "))"
                            }
                        }
                        throw E(errors: errors)
                    }
                }

                case contentParts([ContentPart])
                case text(String)

                public func encode(to encoder: any Encoder) throws {
                    var container = encoder.singleValueContainer()
                    switch self {
                    case let .contentParts(parts):
                        try container.encode(parts)
                    case let .text(text):
                        try container.encode(text)
                    }
                }

                public init(from decoder: any Decoder) throws {
                    let container = try decoder.singleValueContainer()
                    var errors: [Error] = []

                    do {
                        let parts = try container.decode([ContentPart].self)
                        self = .contentParts(parts)
                        return
                    } catch {
                        errors.append(error)
                    }

                    do {
                        let text = try container.decode(String.self)
                        self = .text(text)
                        return
                    } catch {
                        errors.append(error)
                    }

                    do { // Null
                        _ = try container.decode([ContentPart]?.self)
                        self = .contentParts([])
                        return
                    } catch {
                        errors.append(error)
                    }

                    struct E: Error, LocalizedError {
                        let errors: [Error]

                        var errorDescription: String? {
                            "Failed to decode MessageContent: \(errors.map { $0.localizedDescription }.joined(separator: "; "))"
                        }
                    }
                    throw E(errors: errors)
                }
            }

            /// The role of the message.
            public var role: MessageRole
            /// The content of the message.
            public var content: MessageContent
            /// When we want to reply to a function call with the result, we have to provide the
            /// name of the function call, and include the result in `content`.
            ///
            /// - important: It's required when the role is `function`.
            public var name: String?
            /// Tool calls in an assistant message.
            public var tool_calls: [MessageToolCall]?
            /// When we want to call a tool, we have to provide the id of the call.
            ///
            /// - important: It's required when the role is `tool`.
            public var tool_call_id: String?
            /// When the bot wants to call a function, it will reply with a function call.
            ///
            /// Deprecated.
            public var function_call: MessageFunctionCall?
            #warning("TODO: when to use it?")
            /// Cache control for GitHub Copilot models.
            public var copilot_cache_control: GitHubCopilotCacheControl?

            public init(
                role: MessageRole,
                content: MessageContent,
                name: String? = nil,
                tool_calls: [MessageToolCall]? = nil,
                tool_call_id: String? = nil,
                function_call: MessageFunctionCall? = nil,
                copilot_cache_control: GitHubCopilotCacheControl? = nil
            ) {
                self.role = role
                self.content = content
                self.name = name
                self.tool_calls = tool_calls
                self.tool_call_id = tool_call_id
                self.function_call = function_call
                self.copilot_cache_control = copilot_cache_control
            }
        }

        public struct MessageFunctionCall: Codable, Equatable, Sendable {
            /// The name of the
            public var name: String?
            /// A JSON string.
            public var arguments: String?

            public init(name: String? = nil, arguments: String? = nil) {
                self.name = name
                self.arguments = arguments
            }
        }

        public struct MessageToolCall: Codable, Equatable, Sendable {
            /// When it's returned as a data chunk, use the index to identify the tool call.
            public var index: Int?
            /// The id of the tool call.
            public var id: String?
            /// The type of the tool.
            public var type: String?
            /// The function call.
            public var function: MessageFunctionCall?

            public init(
                index: Int? = nil,
                id: String? = nil,
                type: String? = nil,
                function: MessageFunctionCall? = nil
            ) {
                self.index = index
                self.id = id
                self.type = type
                self.function = function
            }
        }

        public struct Tool: Codable, Equatable, Sendable {
            public var type: String = "function"
            public var function: ChatGPTFunctionSchema

            public init(type: String, function: ChatGPTFunctionSchema) {
                self.type = type
                self.function = function
            }
        }

        public struct StreamOptions: Codable, Equatable, Sendable {
            public var include_usage: Bool = true

            public init(include_usage: Bool = true) {
                self.include_usage = include_usage
            }
        }

        public var model: String
        public var messages: [Message]
        public var temperature: Double?
        public var stream: Bool?
        public var stop: [String]?
        public var max_completion_tokens: Int?
        public var tool_choice: FunctionCallStrategy?
        public var tools: [Tool]?
        public var stream_options: StreamOptions?

        public init(
            model: String,
            messages: [Message],
            temperature: Double? = nil,
            stream: Bool? = nil,
            stop: [String]? = nil,
            max_completion_tokens: Int? = nil,
            tool_choice: FunctionCallStrategy? = nil,
            tools: [Tool]? = nil,
            stream_options: StreamOptions? = nil
        ) {
            self.model = model
            self.messages = messages
            self.temperature = temperature
            self.stream = stream
            self.stop = stop
            self.max_completion_tokens = max_completion_tokens
            self.tool_choice = tool_choice
            self.tools = tools
            self.stream_options = stream_options
        }
    }

    var apiKey: String
    var endpoint: URL
    var requestBody: RequestBody
    var model: ChatModel
    let requestModifier: ((inout URLRequest) -> Void)?

    init(
        apiKey: String,
        model: ChatModel,
        endpoint: URL,
        requestBody: ChatCompletionsRequestBody,
        requestModifier: ((inout URLRequest) -> Void)? = nil
    ) {
        self.apiKey = apiKey
        self.endpoint = endpoint
        self.requestBody = .init(
            requestBody,
            endpoint: endpoint,
            enforceMessageOrder: model.info.openAICompatibleInfo.enforceMessageOrder,
            supportsMultipartMessageContent: model.info.openAICompatibleInfo
                .supportsMultipartMessageContent,
            requiresBeginWithUserMessage: model.info.openAICompatibleInfo
                .requiresBeginWithUserMessage,
            canUseTool: model.info.supportsFunctionCalling,
            supportsImage: model.info.supportsImage,
            supportsAudio: model.info.supportsAudio,
            supportsTemperature: {
                guard model.format == .openAI else { return true }
                if let chatGPTModel = ChatGPTModel(rawValue: model.info.modelName) {
                    return chatGPTModel.supportsTemperature
                } else if model.info.modelName.hasPrefix("o") {
                    return false
                }
                return true
            }(),
            supportsSystemPrompt: {
                guard model.format == .openAI else { return true }
                if let chatGPTModel = ChatGPTModel(rawValue: model.info.modelName) {
                    return chatGPTModel.supportsSystemPrompt
                } else if model.info.modelName.hasPrefix("o") {
                    return false
                }
                return true
            }()
        )
        self.model = model
        self.requestModifier = requestModifier
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

        Self.setupCustomBody(&request, model: model)
        Self.setupAppInformation(&request)
        Self.setupAPIKey(&request, model: model, apiKey: apiKey)
        Self.setupGitHubCopilotVisionField(&request, model: model)
        await Self.setupExtraHeaderFields(&request, model: model, apiKey: apiKey)
        requestModifier?(&request)

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
            throw error ?? ChatGPTServiceError.otherError(
                text +
                    "\n\nPlease check your model settings, some capabilities may not be supported by the model."
            )
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
            case .gitHubCopilot:
                break
            case .googleAI:
                assertionFailure("Unsupported")
            case .ollama:
                assertionFailure("Unsupported")
            case .claude:
                assertionFailure("Unsupported")
            }
        }
    }

    static func setupGitHubCopilotVisionField(_ request: inout URLRequest, model: ChatModel) {
        guard model.format == .gitHubCopilot else { return }
        if model.info.supportsImage {
            request.setValue("true", forHTTPHeaderField: "copilot-vision-request")
        }
    }

    static func setupCustomBody(_ request: inout URLRequest, model: ChatModel) {
        switch model.format {
        case .openAI, .openAICompatible:
            break
        default:
            return
        }

        let join = JoinJSON()
        let jsonBody = model.info.customBodyInfo.jsonBody
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = request.httpBody, !jsonBody.isEmpty else { return }
        let newBody = join.join(data, with: jsonBody)
        request.httpBody = newBody
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
                reasoningContent: message.reasoning_content ?? message.reasoning ?? "",
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
                        reasoningContent: choice.delta?.reasoning_content
                            ?? choice.delta?.reasoning,
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
        audios: [ChatCompletionsRequestBody.Message.Audio],
        supportsMultipartMessageContent: Bool
    ) {
        if supportsMultipartMessageContent {
            switch message.role {
            case .system, .developer, .assistant, .user:
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
        } else {
            switch message.role {
            case .system, .developer, .assistant, .user:
                if case let .text(existingText) = message.content {
                    message.content = .text(existingText + "\n\n" + content)
                } else {
                    message.content = .text(content)
                }
            case .tool, .function:
                if case let .text(existingText) = message.content {
                    message.content = .text(existingText + "\n\n" + content)
                } else {
                    message.content = .text(content)
                }
            }
        }
    }

    init(
        _ body: ChatCompletionsRequestBody,
        endpoint: URL,
        enforceMessageOrder: Bool,
        supportsMultipartMessageContent: Bool,
        requiresBeginWithUserMessage: Bool,
        canUseTool: Bool,
        supportsImage: Bool,
        supportsAudio: Bool,
        supportsTemperature: Bool,
        supportsSystemPrompt: Bool
    ) {
        let supportsMultipartMessageContent = if supportsAudio || supportsImage {
            true
        } else {
            supportsMultipartMessageContent
        }
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

        var body = body

        if !supportsTemperature {
            temperature = nil
        }
        if !supportsSystemPrompt {
            for (index, message) in body.messages.enumerated() {
                if message.role == .system {
                    body.messages[index].role = .user
                }
            }
        }

        if requiresBeginWithUserMessage {
            let firstUserIndex = body.messages.firstIndex(where: { $0.role == .user }) ?? 0
            let endIndex = firstUserIndex
            for i in stride(from: endIndex - 1, to: 0, by: -1)
                where i >= 0 && body.messages.endIndex > i
            {
                body.messages.remove(at: i)
            }
        }

        // Special case for Claude through OpenRouter

        if endpoint.absoluteString.contains("openrouter.ai"), model.hasPrefix("anthropic/") {
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
                            audios: supportsAudio ? message.audios : [],
                            supportsMultipartMessageContent: supportsMultipartMessageContent
                        )
                    } else {
                        nonSystemMessages.append(.init(
                            role: .tool,
                            content: {
                                if supportsMultipartMessageContent {
                                    return .contentParts(Self.convertContentPart(
                                        content: message.content,
                                        images: supportsImage ? message.images : [],
                                        audios: supportsAudio ? message.audios : []
                                    ))
                                }
                                return .text(message.content)
                            }(),
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
                            audios: supportsAudio ? message.audios : [],
                            supportsMultipartMessageContent: supportsMultipartMessageContent
                        )
                    } else {
                        nonSystemMessages.append(.init(
                            role: .assistant,
                            content: {
                                if supportsMultipartMessageContent {
                                    return .contentParts(Self.convertContentPart(
                                        content: message.content,
                                        images: supportsImage ? message.images : [],
                                        audios: supportsAudio ? message.audios : []
                                    ))
                                }
                                return .text(message.content)
                            }()
                        ))
                    }
                case (.user, _):
                    if let last = nonSystemMessages.last, last.role == .user {
                        Self.joinMessageContent(
                            &nonSystemMessages[nonSystemMessages.endIndex - 1],
                            content: message.content,
                            images: supportsImage ? message.images : [],
                            audios: supportsAudio ? message.audios : [],
                            supportsMultipartMessageContent: supportsMultipartMessageContent
                        )
                    } else {
                        nonSystemMessages.append(.init(
                            role: .user,
                            content: {
                                if supportsMultipartMessageContent {
                                    return .contentParts(Self.convertContentPart(
                                        content: message.content,
                                        images: supportsImage ? message.images : [],
                                        audios: supportsAudio ? message.audios : []
                                    ))
                                }
                                return .text(message.content)
                            }(),
                            name: message.name,
                            tool_call_id: message.toolCallId
                        ))
                    }
                }
            }
            messages = [
                .init(
                    role: .system,
                    content: {
                        if supportsMultipartMessageContent {
                            return .contentParts(systemPrompts)
                        }
                        let textParts = systemPrompts.compactMap {
                            if case let .text(text) = $0 { return text.text }
                            return nil
                        }

                        return .text(textParts.joined(separator: "\n\n"))
                    }()
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
                content: {
                    // always prefer text only content if possible.
                    if supportsMultipartMessageContent {
                        let images = supportsImage ? message.images : []
                        let audios = supportsAudio ? message.audios : []
                        if !images.isEmpty || !audios.isEmpty {
                            return .contentParts(Self.convertContentPart(
                                content: message.content,
                                images: images,
                                audios: audios
                            ))
                        }
                    }
                    return .text(message.content)
                }(),
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

