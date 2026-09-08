import CopilotForXcodeKit
import Foundation
import AIModel
import Logger
import Preferences

public actor AnthropicService {
    let url: URL
    let modelName: String
    let contextWindow: Int
    let maxToken: Int
    let temperature: Double
    let apiKey: String
    let stopWords: [String]
    let extraHeaders: [(name: String, value: String)]
    let reasoningEffort: ReasoningEffort?
    let customJSONBody: String

    init(
        url: String? = nil,
        modelName: String,
        contextWindow: Int,
        maxToken: Int,
        temperature: Double = 0.2,
        stopWords: [String] = [],
        apiKey: String,
        extraHeaders: [(name: String, value: String)] = [],
        reasoningEffort: ReasoningEffort? = nil,
        customJSONBody: String = ""
    ) {
        self.extraHeaders = extraHeaders
        self.reasoningEffort = reasoningEffort
        self.customJSONBody = customJSONBody
        self.url = url.flatMap(URL.init(string:)) ??
            URL(string: "https://api.anthropic.com/v1/messages")!
        self.modelName = modelName
        self.maxToken = maxToken
        self.temperature = temperature
        self.apiKey = apiKey
        self.stopWords = stopWords
        self.contextWindow = contextWindow
    }

    public enum Models: String, CaseIterable {
        case claude3Opus = "claude-3-opus-latest"
        case claude35Sonnet = "claude-3-5-sonnet-latest"
        case claude35Haiku = "claude-3-5-haiku-latest"

        public var maxToken: Int {
            switch self {
            case .claude3Opus: return 200_000
            case .claude35Sonnet: return 200_000
            case .claude35Haiku: return 200_000
            }
        }
    }
}

// MARK: - CodeCompletionServiceType Implementation

extension AnthropicService: CodeCompletionServiceType {
    typealias CompletionSequence = AsyncThrowingCompactMapSequence<
        ResponseStream<StreamResponse>,
        String
    >

    func getCompletion(_ request: PromptStrategy) async throws -> CompletionSequence {
        let (messages, systemPrompt) = createMessages(from: request)
        CodeCompletionLogger.logger.logPrompt(messages.map {
            ($0.content, $0.role.rawValue)
        })
        let result = try await sendMessages(messages, systemPrompt: systemPrompt)
        return result.compactMap { $0.delta?.text }
    }
}

// MARK: - Message Structure and Request Handling

extension AnthropicService {
    public struct Message: Codable {
        public enum Role: String, Codable {
            case user
            case assistant
        }

        var role: Role
        var content: String
    }

    struct OutputConfig: Codable, Equatable {
        var effort: String
    }

    struct MessageRequestBody: Codable {
        var model: String
        var messages: [Message]
        var system: String?
        var max_tokens: Int
        var temperature: Double
        var stream: Bool = true
        var stop_sequences: [String]?
        var output_config: OutputConfig?

        enum CodingKeys: String, CodingKey {
            case model
            case messages
            case system
            case max_tokens
            case temperature
            case stream
            case stop_sequences
            case output_config
        }
    }

    nonisolated static func outputConfig(for effort: ReasoningEffort?) -> OutputConfig? {
        guard let effort else { return nil }
        let value: String
        switch effort {
        case .low, .medium, .high:
            value = effort.rawValue
        case .none, .minimal:
            value = "low"
        case .xhigh:
            value = "high"
        }
        return .init(effort: value)
    }

    nonisolated static func makeMessageRequestBody(
        modelName: String,
        messages: [Message],
        systemPrompt: String?,
        maxToken: Int,
        temperature: Double,
        stopSequences: [String]?,
        reasoningEffort: ReasoningEffort?
    ) -> MessageRequestBody {
        MessageRequestBody(
            model: modelName,
            messages: messages,
            system: systemPrompt,
            max_tokens: maxToken,
            temperature: temperature,
            stop_sequences: stopSequences,
            output_config: outputConfig(for: reasoningEffort)
        )
    }

    func createMessages(from request: PromptStrategy) -> (messages: [Message], system: String?) {
        let strategy = DefaultTruncateStrategy(maxTokenLimit: max(
            contextWindow / 3 * 2,
            contextWindow - maxToken - 20
        ))
        let prompts = strategy.createTruncatedPrompt(promptStrategy: request)

        let systemPrompt = request.systemPrompt

        let messages = prompts.map { prompt in
            Message(
                role: prompt.role == .user ? .user : .assistant,
                content: prompt.content
            )
        }

        return (messages: messages, system: systemPrompt)
    }

    func sendMessages(_ messages: [Message], systemPrompt: String?) async throws -> ResponseStream<StreamResponse> {
        let validStopSequences = stopWords.filter {
            !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        let requestBody = Self.makeMessageRequestBody(
            modelName: modelName,
            messages: messages,
            systemPrompt: systemPrompt,
            maxToken: maxToken,
            temperature: temperature,
            stopSequences: validStopSequences,
            reasoningEffort: reasoningEffort
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue("\(apiKey)", forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setExtraHeaders(extraHeaders)

        let encoder = JSONEncoder()
        request.httpBody = CompletionJSON.mergeCustomBody(
            try encoder.encode(requestBody),
            jsonBody: customJSONBody
        )

        let (result, response) = try await URLSession.shared.bytes(for: request)
        return try await CompletionHTTP.makeStream(
            result: result,
            response: response,
            mapError: { Error.otherError($0) },
            parseBody: { try Self.parseMessageBody($0, url: url) },
            parseLine: Self.parseStreamLine
        )
    }

    static func parseMessageBody(_ text: String, url: URL) throws -> StreamResponse {
        if let message = APIErrorPayload.message(in: text) {
            throw Error.apiError(APIError(type: "error", message: message, code: nil))
        }
        do {
            let body = try JSONDecoder().decode(StreamResponse.self, from: Data(text.utf8))
            let joined = (body.content ?? []).map(\.text).joined()
            return StreamResponse(
                type: body.type ?? "message",
                delta: .init(text: joined, type: "text"),
                index: nil,
                content: body.content
            )
        } catch let error as Error {
            throw error
        } catch {
            throw Error.otherError(CompletionHTTP.parseFailureMessage(url: url))
        }
    }

    static func parseStreamLine(_ line: String) throws -> ResponseStream<StreamResponse>.LineContent {
        guard let payload = SSELine.payload(of: line) else {
            return .init(chunk: nil, done: false)
        }
        struct ErrorEvent: Decodable {
            var type: String?
            var error: APIError?
        }
        if let event = try? JSONDecoder().decode(ErrorEvent.self, from: Data(payload.utf8)),
           event.type == "error"
        {
            if let error = event.error {
                throw Error.apiError(error)
            }
            throw Error.otherError("Unknown error.")
        }
        do {
            let chunk = try JSONDecoder().decode(StreamResponse.self, from: Data(payload.utf8))
            return .init(chunk: chunk, done: chunk.type == "message_stop")
        } catch {
            Logger.service.error("Error decoding chunk: \(error)")
            throw error
        }
    }
}

// MARK: - API Response Structures

extension AnthropicService {
    struct StreamResponse: Decodable {
        var type: String?
        var delta: Delta?
        var index: Int?
        var content: [Content]?

        struct Delta: Decodable {
            var text: String?
            var type: String?
        }

        struct Content: Decodable {
            var text: String
            var type: String
        }
    }

    struct APIError: Decodable {
        var type: String
        var message: String
        var code: String?
    }

    enum Error: Swift.Error, LocalizedError {
        case decodeError(Swift.Error)
        case apiError(APIError)
        case otherError(String)

        var errorDescription: String? {
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
}

// MARK: - Helper Methods

extension AnthropicService {
    func validateResponse(_ response: HTTPURLResponse) throws {
        guard (200 ... 299).contains(response.statusCode) else {
            throw Error.otherError("HTTP Error: \(response.statusCode)")
        }
    }
}
