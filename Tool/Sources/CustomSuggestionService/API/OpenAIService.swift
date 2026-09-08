import CopilotForXcodeKit
import Foundation
import AIModel
import Logger
import Preferences

public actor OpenAIService {
    let url: URL
    let endpoint: Endpoint
    let modelName: String
    let contextWindow: Int
    let maxToken: Int
    let temperature: Double
    let apiKey: String
    let stopWords: [String]
    /// When set, the request takes the reasoning model shape: `reasoning_effort` is sent,
    /// `max_completion_tokens` replaces `max_tokens`, `temperature` and `stop` are omitted.
    let reasoningEffort: ReasoningEffort?
    let reasoningTokenBudget: Int
    let extraHeaders: [(name: String, value: String)]
    let organizationID: String
    let projectID: String
    let customJSONBody: String
    let requiresBeginWithUserMessage: Bool
    let enforceMessageOrder: Bool
    let authentication: Authentication

    public enum Endpoint {
        case completion
        case chatCompletion
    }

    public enum Authentication {
        case bearer
        case apiKeyHeader
    }

    init(
        url: String? = nil,
        endpoint: Endpoint,
        modelName: String,
        contextWindow: Int,
        maxToken: Int,
        temperature: Double = 0.2,
        stopWords: [String] = [],
        apiKey: String,
        authentication: Authentication = .bearer,
        reasoningEffort: ReasoningEffort? = nil,
        reasoningTokenBudget: Int = 1500,
        extraHeaders: [(name: String, value: String)] = [],
        organizationID: String = "",
        projectID: String = "",
        customJSONBody: String = "",
        requiresBeginWithUserMessage: Bool = false,
        enforceMessageOrder: Bool = false
    ) throws {
        self.authentication = authentication
        self.reasoningEffort = reasoningEffort
        self.reasoningTokenBudget = reasoningTokenBudget
        self.extraHeaders = extraHeaders
        self.organizationID = organizationID
        self.projectID = projectID
        self.customJSONBody = customJSONBody
        self.requiresBeginWithUserMessage = requiresBeginWithUserMessage
        self.enforceMessageOrder = enforceMessageOrder
        self.url = try Self.resolveURL(
            url: url,
            authentication: authentication,
            endpoint: endpoint
        )

        self.endpoint = endpoint
        self.modelName = modelName
        self.maxToken = maxToken
        self.temperature = temperature
        self.apiKey = apiKey
        self.stopWords = stopWords
        self.contextWindow = contextWindow
    }

    nonisolated static let missingAzureEndpointMessage =
        "Azure OpenAI endpoint is empty. Set the resource base URL."

    /// Matches `ChatModel.endpoint` / `CompletionModel.endpoint` Azure branches.
    nonisolated static func azureEndpoint(
        baseURL: String,
        deployment: String,
        endpoint: Endpoint
    ) -> String {
        switch endpoint {
        case .chatCompletion:
            let version = "2024-09-01-preview"
            if baseURL.isEmpty { return "" }
            return "\(baseURL)/openai/deployments/\(deployment)/chat/completions?api-version=\(version)"
        case .completion:
            let version = "2023-07-01-preview"
            if baseURL.isEmpty { return "" }
            return "\(baseURL)/openai/deployments/\(deployment)/completions?api-version=\(version)"
        }
    }

    /// Azure (`api-key`) must not fall back to api.openai.com.
    nonisolated static func resolveURL(
        url: String?,
        authentication: Authentication,
        endpoint: Endpoint
    ) throws -> URL {
        if let url, !url.isEmpty, let parsed = URL(string: url) {
            if authentication == .apiKeyHeader, isOpenAIAPIHost(parsed) {
                throw Error.otherError(missingAzureEndpointMessage)
            }
            return parsed
        }
        if authentication == .apiKeyHeader {
            throw Error.otherError(missingAzureEndpointMessage)
        }
        switch endpoint {
        case .chatCompletion:
            return URL(string: "https://api.openai.com/v1/chat/completions")!
        case .completion:
            return URL(string: "https://api.openai.com/v1/completions")!
        }
    }

    nonisolated static func isOpenAIAPIHost(_ url: URL) -> Bool {
        url.host == "api.openai.com"
    }
}

extension OpenAIService: CodeCompletionServiceType {
    typealias CompletionSequence = AsyncThrowingCompactMapSequence<
        ResponseStream<ChatCompletionsStreamDataChunk>,
        String
    >

    func getCompletion(_ request: PromptStrategy) async throws -> CompletionSequence {
        switch endpoint {
        case .chatCompletion:
            let messages = createMessages(from: request)
            CodeCompletionLogger.logger.logPrompt(messages.map {
                ($0.content, $0.role.rawValue)
            })
            let result = try await sendMessages(messages)
            return result.compactMap { $0.choices?.first?.delta?.content }
        case .completion:
            let prompt = createPrompt(from: request)
            CodeCompletionLogger.logger.logPrompt([(prompt, "user")])
            let result = try await sendPrompt(prompt)
            return result.compactMap { $0.choices?.first?.delta?.content }
        }
    }
}

public extension OpenAIService {
    enum Error: Swift.Error, LocalizedError {
        case apiError(String)
        case otherError(String)

        public var errorDescription: String? {
            switch self {
            case let .apiError(message), let .otherError(message):
                return message
            }
        }
    }
}

// MARK: - Chat Completion API

extension OpenAIService {
    public struct Message: Codable, Equatable {
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

    func createMessages(from request: PromptStrategy) -> [Message] {
        let strategy = DefaultTruncateStrategy(maxTokenLimit: max(
            contextWindow / 3 * 2,
            contextWindow - maxToken - 20
        ))
        let prompts = strategy.createTruncatedPrompt(promptStrategy: request)
        var ordered: [OrderedChatMessage] = [
            .init(role: .system, content: request.systemPrompt),
        ]
        for prompt in prompts {
            switch prompt.role {
            case .user:
                ordered.append(.init(role: .user, content: prompt.content))
            case .assistant:
                ordered.append(.init(role: .assistant, content: prompt.content))
            }
        }
        ordered = OrderedChatMessages.apply(
            ordered,
            requiresBeginWithUserMessage: requiresBeginWithUserMessage,
            enforceMessageOrder: enforceMessageOrder
        )
        return ordered.map { message in
            let role: Message.Role = switch message.role {
            case .system: .system
            case .user: .user
            case .assistant: .assistant
            }
            return .init(role: role, content: message.content)
        }
    }

    nonisolated static func makeChatCompletionRequestBody(
        modelName: String,
        messages: [Message],
        temperature: Double,
        stopWords: [String],
        maxToken: Int,
        reasoningEffort: ReasoningEffort?,
        reasoningTokenBudget: Int
    ) -> ChatCompletionRequestBody {
        let isReasoningRequest = reasoningEffort != nil
        return ChatCompletionRequestBody(
            model: modelName,
            messages: messages,
            temperature: isReasoningRequest ? nil : temperature,
            stream: true,
            stop: isReasoningRequest ? nil : stopWords,
            max_tokens: isReasoningRequest ? nil : maxToken,
            max_completion_tokens: isReasoningRequest
                ? ReasoningTokenLimit.maxOutputTokens(
                    maxToken: maxToken,
                    effort: reasoningEffort,
                    budget: reasoningTokenBudget
                )
                : nil,
            reasoning_effort: reasoningEffort?.rawValue
        )
    }

    func sendMessages(
        _ messages: [Message]
    ) async throws -> ResponseStream<ChatCompletionsStreamDataChunk> {
        let requestBody = Self.makeChatCompletionRequestBody(
            modelName: modelName,
            messages: messages,
            temperature: temperature,
            stopWords: stopWords,
            maxToken: maxToken,
            reasoningEffort: reasoningEffort,
            reasoningTokenBudget: reasoningTokenBudget
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let encoder = JSONEncoder()
        request.httpBody = CompletionJSON.mergeCustomBody(
            try encoder.encode(requestBody),
            jsonBody: customJSONBody
        )
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        applyAuthentication(to: &request)
        request.setOpenAIIdentityHeaders(organizationID: organizationID, projectID: projectID)
        request.setExtraHeaders(extraHeaders)
        let (result, response) = try await URLSession.shared.bytes(for: request)
        return try await CompletionHTTP.makeStream(
            result: result,
            response: response,
            mapError: { Error.otherError($0) },
            parseBody: { try Self.parseChatCompletionsBody($0, url: url) },
            parseLine: Self.parseChatCompletionsStreamLine
        )
    }

    func applyAuthentication(to request: inout URLRequest) {
        switch authentication {
        case .bearer:
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        case .apiKeyHeader:
            request.setValue(apiKey, forHTTPHeaderField: "api-key")
        }
    }

    /// Parses a non-streaming `application/json` chat completions body.
    static func parseChatCompletionsBody(
        _ text: String,
        url: URL
    ) throws -> ChatCompletionsStreamDataChunk {
        if let message = APIErrorPayload.message(in: text) {
            throw Error.apiError(message)
        }
        do {
            let body = try JSONDecoder().decode(
                ChatCompletionResponseBody.self,
                from: Data(text.utf8)
            )
            let chunk = chatChunk(from: body)
            logIfTruncatedByLength(chunk)
            return chunk
        } catch let error as Error {
            throw error
        } catch {
            throw Error.otherError(CompletionHTTP.parseFailureMessage(url: url))
        }
    }

    static func logIfTruncatedByLength(_ chunk: ChatCompletionsStreamDataChunk) {
        if chunk.choices?.first?.finish_reason == "length" {
            Logger.service.error(
                "Completion truncated: finish_reason=length request_id=\(chunk.id ?? "unknown")"
            )
        }
    }

    static func chatChunk(from body: ChatCompletionResponseBody) -> ChatCompletionsStreamDataChunk {
        let choice = body.choices.first
        return ChatCompletionsStreamDataChunk(
            id: body.id,
            object: body.object,
            model: body.model,
            choices: [
                .init(
                    delta: .init(role: choice?.message.role, content: choice?.message.content),
                    index: choice?.index,
                    finish_reason: choice?.finish_reason ?? "stop",
                    message: choice?.message
                ),
            ]
        )
    }

    static func asChatChunk(_ chunk: CompletionsStreamDataChunk) -> ChatCompletionsStreamDataChunk {
        ChatCompletionsStreamDataChunk(
            id: chunk.id,
            object: chunk.object,
            model: chunk.model,
            choices: chunk.choices?.map { choice in
                .init(
                    delta: .init(role: nil, content: choice.text),
                    index: choice.index,
                    finish_reason: choice.finish_reason,
                    message: nil
                )
            }
        )
    }

    /// Parses one line of the event stream.
    static func parseChatCompletionsStreamLine(
        _ line: String
    ) throws -> ResponseStream<ChatCompletionsStreamDataChunk>.LineContent {
        guard let payload = SSELine.payload(of: line) else { return .init(chunk: nil, done: false) }
        if payload == "[DONE]" { return .init(chunk: nil, done: true) }
        if let message = APIErrorPayload.message(in: payload) {
            throw Error.apiError(message)
        }
        let chunk = try JSONDecoder().decode(
            ChatCompletionsStreamDataChunk.self,
            from: Data(payload.utf8)
        )
        logIfTruncatedByLength(chunk)
        // A non-streaming body carries the whole message instead of a delta.
        if let choice = chunk.choices?.first, choice.delta == nil, let message = choice.message {
            return .init(
                chunk: .init(choices: [.init(
                    delta: .init(role: message.role, content: message.content),
                    index: choice.index,
                    finish_reason: choice.finish_reason ?? "stop",
                    message: nil
                )]),
                done: true
            )
        }
        return .init(chunk: chunk, done: chunk.choices?.first?.finish_reason != nil)
    }

    /// https://platform.openai.com/docs/api-reference/chat/create
    struct ChatCompletionRequestBody: Codable, Equatable {
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
        /// Reasoning models reject `max_tokens` and expect this field instead.
        var max_completion_tokens: Int?
        var reasoning_effort: String?

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
            max_completion_tokens: Int? = nil,
            reasoning_effort: String? = nil
        ) {
            self.max_completion_tokens = max_completion_tokens
            self.reasoning_effort = reasoning_effort
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
        }
    }

    struct ChatCompletionResponseBody: Codable, Equatable {
        struct Choice: Codable, Equatable {
            var message: Message
            var index: Int
            var finish_reason: String?
        }

        struct Usage: Codable, Equatable {
            var prompt_tokens: Int
            var completion_tokens: Int
            var total_tokens: Int
        }

        var id: String?
        var object: String?
        var model: String?
        var usage: Usage?
        var choices: [Choice]
    }

    struct ChatCompletionsStreamDataChunk: Decodable {
        var id: String?
        var object: String?
        var model: String?
        var choices: [Choice]?

        struct Choice: Decodable {
            var delta: Delta?
            var index: Int?
            var finish_reason: String?
            /// Present in a non-streaming response body.
            var message: Message?

            struct Delta: Decodable {
                var role: Message.Role?
                var content: String?
            }
        }
    }
}

// MARK: - Completion API

extension OpenAIService {
    func createPrompt(from request: PromptStrategy) -> String {
        let strategy = DefaultTruncateStrategy(maxTokenLimit: max(
            contextWindow / 3 * 2,
            contextWindow - maxToken - 20
        ))
        let prompts = strategy.createTruncatedPrompt(promptStrategy: request)
        // if request.systemPrompt empty not append
        if  request.systemPrompt.isEmpty {
            return prompts.map(\.content).joined(separator: "\n\n")
        }
        return ([request.systemPrompt] + prompts.map(\.content)).joined(separator: "\n\n")
    }

    func sendPrompt(_ prompt: String) async throws -> ResponseStream<ChatCompletionsStreamDataChunk> {
        let requestBody = CompletionRequestBody(
            model: modelName,
            prompt: prompt,
            temperature: temperature,
            stream: true,
            stop: stopWords,
            max_tokens: maxToken
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let encoder = JSONEncoder()
        request.httpBody = CompletionJSON.mergeCustomBody(
            try encoder.encode(requestBody),
            jsonBody: customJSONBody
        )
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        applyAuthentication(to: &request)
        request.setOpenAIIdentityHeaders(organizationID: organizationID, projectID: projectID)
        request.setExtraHeaders(extraHeaders)
        let (result, response) = try await URLSession.shared.bytes(for: request)
        return try await CompletionHTTP.makeStream(
            result: result,
            response: response,
            mapError: { Error.otherError($0) },
            parseBody: { try Self.asChatChunk(Self.parseCompletionsBody($0, url: url)) },
            parseLine: { line in
                let content = try Self.parseCompletionsStreamLine(line)
                return .init(chunk: content.chunk.map(Self.asChatChunk), done: content.done)
            }
        )
    }

    static func parseCompletionsBody(
        _ text: String,
        url: URL
    ) throws -> CompletionsStreamDataChunk {
        if let message = APIErrorPayload.message(in: text) {
            throw Error.apiError(message)
        }
        do {
            let body = try JSONDecoder().decode(CompletionResponseBody.self, from: Data(text.utf8))
            return CompletionsStreamDataChunk(
                id: body.id,
                object: body.object,
                model: body.model,
                choices: body.choices.map {
                    .init(text: $0.text, index: $0.index, finish_reason: $0.finish_reason)
                }
            )
        } catch let error as Error {
            throw error
        } catch {
            throw Error.otherError(CompletionHTTP.parseFailureMessage(url: url))
        }
    }

    /// Parses one line of the event stream.
    static func parseCompletionsStreamLine(
        _ line: String
    ) throws -> ResponseStream<CompletionsStreamDataChunk>.LineContent {
        guard let payload = SSELine.payload(of: line) else { return .init(chunk: nil, done: false) }
        if payload == "[DONE]" { return .init(chunk: nil, done: true) }
        if let message = APIErrorPayload.message(in: payload) {
            throw Error.apiError(message)
        }
        let chunk = try JSONDecoder().decode(CompletionsStreamDataChunk.self, from: Data(payload.utf8))
        return .init(chunk: chunk, done: chunk.choices?.first?.finish_reason != nil)
    }

    /// https://platform.openai.com/docs/api-reference/chat/create
    struct CompletionRequestBody: Codable, Equatable {
        var model: String
        var prompt: String
        var temperature: Double?
        var top_p: Double?
        var n: Double?
        var stream: Bool?
        var stop: [String]?
        /// Default to be 16.
        var max_tokens: Int?
        var presence_penalty: Double?
        var frequency_penalty: Double?
        var logit_bias: [String: Double]?

        init(
            model: String,
            prompt: String,
            temperature: Double? = nil,
            top_p: Double? = nil,
            n: Double? = nil,
            stream: Bool? = nil,
            stop: [String]? = nil,
            max_tokens: Int? = nil,
            presence_penalty: Double? = nil,
            frequency_penalty: Double? = nil,
            logit_bias: [String: Double]? = nil
        ) {
            self.model = model
            self.prompt = prompt
            self.temperature = temperature
            self.top_p = top_p
            self.n = n
            self.stream = stream
            self.stop = stop
            self.max_tokens = max_tokens
            self.presence_penalty = presence_penalty
            self.frequency_penalty = frequency_penalty
            self.logit_bias = logit_bias
        }
    }

    struct CompletionResponseBody: Codable, Equatable {
        struct Choice: Codable, Equatable {
            var text: String
            var index: Int
            var finish_reason: String?
        }

        struct Usage: Codable, Equatable {
            var prompt_tokens: Int
            var total_tokens: Int
        }

        var id: String?
        var object: String?
        var model: String?
        var usage: Usage?
        var choices: [Choice]
    }

    struct CompletionsStreamDataChunk: Decodable {
        struct Choice: Decodable {
            var text: String?
            var index: Int
            var finish_reason: String?
        }

        var id: String?
        var object: String?
        var model: String?
        var choices: [Choice]?
    }
}
