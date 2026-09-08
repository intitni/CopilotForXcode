import CopilotForXcodeKit
import Foundation
import AIModel

public actor OllamaService {
    let url: URL
    let endpoint: Endpoint
    let modelName: String
    let maxToken: Int
    let contextWindow: Int
    let temperature: Double
    let stopWords: [String]
    let keepAlive: String
    let format: ResponseFormat
    let authenticationMode: AuthenticationMode?
    
    enum AuthenticationMode {
        case bearerToken(String)
        case header(name: String, value: String)
    }

    public enum ResponseFormat: String {
        case none = ""
        case json
    }

    public enum Endpoint {
        case completion
        case chatCompletion
        case completionWithSuffix
    }

    init(
        url: String? = nil,
        endpoint: Endpoint,
        modelName: String,
        contextWindow: Int,
        maxToken: Int,
        temperature: Double = 0.2,
        stopWords: [String] = [],
        keepAlive: String = "",
        format: ResponseFormat = .none,
        authenticationMode: AuthenticationMode? = nil
    ) {
        self.url = url.flatMap(URL.init(string:)) ?? {
            switch endpoint {
            case .chatCompletion:
                URL(string: "https://127.0.0.1:11434/api/chat")!
            case .completion, .completionWithSuffix:
                URL(string: "https://127.0.0.1:11434/api/generate")!
            }
        }()

        self.endpoint = endpoint
        self.modelName = modelName
        self.maxToken = maxToken
        self.temperature = temperature
        self.stopWords = stopWords
        self.keepAlive = keepAlive
        self.format = format
        self.contextWindow = contextWindow
        self.authenticationMode = authenticationMode
    }
}

extension OllamaService: CodeCompletionServiceType {
    typealias CompletionSequence = AsyncThrowingCompactMapSequence<
        ResponseStream<OllamaService.ChatCompletionResponseChunk>,
        String
    >

    func getCompletion(
        _ request: PromptStrategy
    ) async throws -> CompletionSequence {
        switch endpoint {
        case .chatCompletion:
            let messages = createMessages(from: request)
            CodeCompletionLogger.logger.logPrompt(messages.map {
                ($0.content, $0.role.rawValue)
            })
            let stream = try await sendMessages(messages)
            return stream.compactMap { $0.message?.content }
        case .completion:
            let prompt = createPrompt(from: request)
            CodeCompletionLogger.logger.logPrompt([(prompt, "user")])
            let stream = try await sendPrompt(prompt, raw: request.promptIsRaw)
            return stream.compactMap { $0.response }
        case .completionWithSuffix:
            let strategy = DefaultTruncateStrategy(maxTokenLimit: max(
                contextWindow / 3 * 2,
                contextWindow - maxToken - 20
            ))
            let prompts = strategy.createTruncatedPrompt(promptStrategy: request)

            let prefix = prompts.first { $0.role == .prefix }?.content ?? ""
            let suffix = prompts.last { $0.role == .suffix }?.content ?? ""

            CodeCompletionLogger.logger.logPrompt([
                (prefix, "prefix"),
                (suffix, "suffix"),
            ])

            let stream = try await sendPrompt(prefix, suffix: suffix)
            return stream.compactMap { $0.response }
        }
    }
}

extension OllamaService {
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
extension OllamaService {
    struct ChatCompletionRequestBody: Codable {
        struct Options: Codable {
            var temperature: Double
            var stop: [String]
            var num_predict: Int
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

    func sendMessages(_ messages: [Message]) async throws
        -> ResponseStream<ChatCompletionResponseChunk>
    {
        let requestBody = ChatCompletionRequestBody(
            model: modelName,
            messages: messages,
            stream: true,
            options: .init(
                temperature: temperature,
                stop: stopWords,
                num_predict: maxToken
            ),
            keep_alive: keepAlive.isEmpty ? nil : keepAlive,
            format: format == .none ? nil : format.rawValue
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(requestBody)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let (result, response) = try await URLSession.shared.bytes(for: request)
        return try await CompletionHTTP.makeStream(
            result: result,
            response: response,
            mapError: { Error.otherError($0) },
            parseBody: { try Self.parseChunkBody($0, url: url) },
            parseLine: Self.parseStreamLine
        )
    }

    static func parseChunkBody(_ text: String, url: URL) throws -> ChatCompletionResponseChunk {
        do {
            return try JSONDecoder().decode(ChatCompletionResponseChunk.self, from: Data(text.utf8))
        } catch {
            throw Error.otherError(CompletionHTTP.parseFailureMessage(url: url))
        }
    }

    static func parseStreamLine(_ line: String) throws -> ResponseStream<ChatCompletionResponseChunk>.LineContent {
        let chunk = try JSONDecoder().decode(
            ChatCompletionResponseChunk.self,
            from: line.data(using: .utf8) ?? Data()
        )
        return .init(chunk: chunk, done: chunk.done)
    }
}

// MARK: - Completion API

extension OllamaService {
    struct CompletionRequestBody: Codable {
        var model: String
        var prompt: String
        var stream: Bool
        var options: ChatCompletionRequestBody.Options
        var keep_alive: String?
        var format: String?
        var raw: Bool?
        var suffix: String?
    }

    func createPrompt(from request: PromptStrategy) -> String {
        let strategy = DefaultTruncateStrategy(maxTokenLimit: max(
            contextWindow / 3 * 2,
            contextWindow - maxToken - 20
        ))
        let prompts = strategy.createTruncatedPrompt(promptStrategy: request)
        return ([request.systemPrompt] + prompts.map(\.content)).joined(separator: "\n\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func sendPrompt(
        _ prompt: String,
        raw: Bool? = nil,
        suffix: String? = nil
    ) async throws -> ResponseStream<ChatCompletionResponseChunk> {
        let requestBody = CompletionRequestBody(
            model: modelName,
            prompt: prompt,
            stream: true,
            options: .init(
                temperature: temperature,
                stop: stopWords,
                num_predict: maxToken
            ),
            keep_alive: keepAlive.isEmpty ? nil : keepAlive,
            format: format == .none ? nil : format.rawValue,
            raw: raw,
            suffix: suffix
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(requestBody)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        switch authenticationMode{
        case .none:
            break
        case let .bearerToken(key):
            request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        case let .header(name, value):
            request.setValue(value, forHTTPHeaderField: name)
        }
        
        let (result, response) = try await URLSession.shared.bytes(for: request)
        return try await CompletionHTTP.makeStream(
            result: result,
            response: response,
            mapError: { Error.otherError($0) },
            parseBody: { try Self.parseChunkBody($0, url: url) },
            parseLine: Self.parseStreamLine
        )
    }

    func countToken(_ message: Message) -> Int {
        message.content.count
    }
}

