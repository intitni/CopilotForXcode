import CopilotForXcodeKit
import Foundation
import AIModel

public actor OpenAIService {
    let url: URL
    let endpoint: Endpoint
    let modelName: String
    let contextWindow: Int
    let maxToken: Int
    let temperature: Double
    let apiKey: String
    let stopWords: [String]

    public enum Endpoint {
        case completion
        case chatCompletion
    }

    init(
        url: String? = nil,
        endpoint: Endpoint,
        modelName: String,
        contextWindow: Int,
        maxToken: Int,
        temperature: Double = 0.2,
        stopWords: [String] = [],
        apiKey: String
    ) {
        self.url = url.flatMap(URL.init(string:)) ?? {
            switch endpoint {
            case .chatCompletion:
                URL(string: "https://api.openai.com/v1/chat/completions")!
            case .completion:
                URL(string: "https://api.openai.com/v1/completions")!
            }
        }()

        self.endpoint = endpoint
        self.modelName = modelName
        self.maxToken = maxToken
        self.temperature = temperature
        self.apiKey = apiKey
        self.stopWords = stopWords
        self.contextWindow = contextWindow
    }
}

extension OpenAIService: CodeCompletionServiceType {
    func getCompletion(_ request: PromptStrategy) async throws -> AsyncStream<String> {
        switch endpoint {
        case .chatCompletion:
            let messages = createMessages(from: request)
            CodeCompletionLogger.logger.logPrompt(messages.map {
                ($0.content, $0.role.rawValue)
            })
            let result = try await sendMessages(messages)
            return result.compactMap { $0.choices?.first?.delta?.content }.eraseToStream()
        case .completion:
            let prompt = createPrompt(from: request)
            CodeCompletionLogger.logger.logPrompt([(prompt, "user")])
            let result = try await sendPrompt(prompt)
            return result.compactMap { $0.choices?.first?.text }.eraseToStream()
        }
    }
}

public extension OpenAIService {
    struct APIError: Decodable {
        var message: String
        var type: String
        var param: String
        var code: String
    }

    enum Error: Swift.Error, LocalizedError {
        case decodeError(Swift.Error)
        case apiError(APIError)
        case otherError(String)

        public var errorDescription: String? {
            switch self {
            case let .decodeError(error):
                return error.localizedDescription
            case let .apiError(error):
                return error.message
            case let .otherError(message):
                return message
            }
        }
    }

    func countToken(_ message: Message) -> Int {
        message.content.count
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
        return [
            .init(role: .system, content: request.systemPrompt),
        ] + prompts.map { prompt in
            switch prompt.role {
            case .user:
                return .init(role: .user, content: prompt.content)
            case .assistant:
                return .init(role: .assistant, content: prompt.content)
            }
        }
    }

    func sendMessages(
        _ messages: [Message]
    ) async throws -> ResponseStream<ChatCompletionsStreamDataChunk> {
        let requestBody = ChatCompletionRequestBody(
            model: modelName,
            messages: messages,
            temperature: temperature,
            stream: true,
            stop: stopWords,
            max_tokens: maxToken
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(requestBody)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
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

        return ResponseStream(result: result) {
            var text = $0
            if text.hasPrefix("data: ") {
                text = String(text.dropFirst(6))
            }
            do {
                let chunk = try JSONDecoder().decode(
                    ChatCompletionsStreamDataChunk.self,
                    from: text.data(using: .utf8) ?? Data()
                )
                return .init(chunk: chunk, done: chunk.choices?.first?.finish_reason != nil)
            } catch {
                print(error)
                throw error
            }
        }
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
            logit_bias: [String: Double]? = nil
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
        }
    }

    struct ChatCompletionResponseBody: Codable, Equatable {
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

    struct ChatCompletionsStreamDataChunk: Decodable {
        var id: String?
        var object: String?
        var model: String?
        var choices: [Choice]?

        struct Choice: Decodable {
            var delta: Delta?
            var index: Int?
            var finish_reason: String?

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

    func sendPrompt(_ prompt: String) async throws -> ResponseStream<CompletionsStreamDataChunk> {
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
        request.httpBody = try encoder.encode(requestBody)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
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

        return ResponseStream(result: result) {
            var text = $0
            if text.hasPrefix("data: ") {
                text = String(text.dropFirst(6))
            }
            do {
                let chunk = try JSONDecoder().decode(
                    CompletionsStreamDataChunk.self,
                    from: text.data(using: .utf8) ?? Data()
                )
                return .init(chunk: chunk, done: chunk.choices?.first?.finish_reason != nil)
            } catch {
                print(error)
                throw error
            }
        }
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
            var finish_reason: String
        }

        struct Usage: Codable, Equatable {
            var prompt_tokens: Int
            var total_tokens: Int
        }

        var id: String?
        var object: String
        var model: String
        var usage: Usage
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

// MARK: - Models

public extension OpenAIService {
    public enum ChatCompletionModels: String, CaseIterable {
        case gpt35Turbo = "gpt-3.5-turbo"
        case gpt35Turbo16k = "gpt-3.5-turbo-16k"
        case gpt4 = "gpt-4"
        case gpt432k = "gpt-4-32k"
        case gpt4TurboPreview = "gpt-4-turbo-preview"
        case gpt40314 = "gpt-4-0314"
        case gpt40613 = "gpt-4-0613"
        case gpt41106Preview = "gpt-4-1106-preview"
        case gpt4VisionPreview = "gpt-4-vision-preview"
        case gpt35Turbo0301 = "gpt-3.5-turbo-0301"
        case gpt35Turbo0613 = "gpt-3.5-turbo-0613"
        case gpt35Turbo1106 = "gpt-3.5-turbo-1106"
        case gpt35Turbo0125 = "gpt-3.5-turbo-0125"
        case gpt35Turbo16k0613 = "gpt-3.5-turbo-16k-0613"
        case gpt432k0314 = "gpt-4-32k-0314"
        case gpt432k0613 = "gpt-4-32k-0613"
        case gpt40125 = "gpt-4-0125-preview"
    }

    public enum CompletionModels: String, CaseIterable {
        case gpt35TurboInstruct = "gpt-3.5-turbo-instruct"
    }
}

public extension OpenAIService.ChatCompletionModels {
    public var maxToken: Int {
        switch self {
        case .gpt4:
            return 8192
        case .gpt40314:
            return 8192
        case .gpt432k:
            return 32768
        case .gpt432k0314:
            return 32768
        case .gpt35Turbo:
            return 4096
        case .gpt35Turbo0301:
            return 4096
        case .gpt35Turbo0613:
            return 4096
        case .gpt35Turbo1106:
            return 16385
        case .gpt35Turbo0125:
            return 16385
        case .gpt35Turbo16k:
            return 16385
        case .gpt35Turbo16k0613:
            return 16385
        case .gpt40613:
            return 8192
        case .gpt432k0613:
            return 32768
        case .gpt41106Preview:
            return 128_000
        case .gpt4VisionPreview:
            return 128_000
        case .gpt4TurboPreview:
            return 128_000
        case .gpt40125:
            return 128_000
        }
    }
}

public extension OpenAIService.CompletionModels {
    public var maxToken: Int {
        switch self {
        case .gpt35TurboInstruct:
            return 4096
        }
    }
}

