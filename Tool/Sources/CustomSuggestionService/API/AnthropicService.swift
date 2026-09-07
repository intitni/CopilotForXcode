import CopilotForXcodeKit
import Foundation
import AIModel

public actor AnthropicService {
    let url: URL
    let modelName: String
    let contextWindow: Int
    let maxToken: Int
    let temperature: Double
    let apiKey: String
    let stopWords: [String]
    let extraHeaders: [(name: String, value: String)]

    init(
        url: String? = nil,
        modelName: String,
        contextWindow: Int,
        maxToken: Int,
        temperature: Double = 0.2,
        stopWords: [String] = [],
        apiKey: String,
        extraHeaders: [(name: String, value: String)] = []
    ) {
        self.extraHeaders = extraHeaders
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
    func getCompletion(_ request: PromptStrategy) async throws -> AsyncStream<String> {
        let (messages, systemPrompt) = createMessages(from: request)
        CodeCompletionLogger.logger.logPrompt(messages.map {
            ($0.content, $0.role.rawValue)
        })
        let result = try await sendMessages(messages, systemPrompt: systemPrompt)
        return result.compactMap { $0.delta?.text }.eraseToStream()
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

    struct MessageRequestBody: Codable {
        var model: String
        var messages: [Message]
        var system: String?
        var max_tokens: Int
        var temperature: Double
        var stream: Bool = true
        var stop_sequences: [String]?

        enum CodingKeys: String, CodingKey {
            case model
            case messages
            case system
            case max_tokens
            case temperature
            case stream
            case stop_sequences
        }
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

        let requestBody = MessageRequestBody(
            model: modelName,
            messages: messages,
            system: systemPrompt,
            max_tokens: maxToken,
            temperature: temperature,
            stop_sequences: validStopSequences
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue("\(apiKey)", forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setExtraHeaders(extraHeaders)

        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(requestBody)

        let (result, response) = try await URLSession.shared.bytes(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw CancellationError()
        }

        guard httpResponse.statusCode == 200 else {
            let text = try await result.lines.reduce(into: "") { partialResult, current in
                partialResult += current
            }
            throw Error.otherError(text)
        }

        return ResponseStream(result: result) {
            var text = $0

            if text.hasPrefix("event: ") {
                return .init(chunk: StreamResponse(), done: false)
            }

            if text.hasPrefix("data: ") {
                text = String(text.dropFirst(6))

                guard !text.trimmingCharacters(in: .whitespaces).isEmpty else {
                    return .init(chunk: StreamResponse(), done: false)
                }

                do {
                    let chunk = try JSONDecoder().decode(
                        StreamResponse.self,
                        from: text.data(using: .utf8) ?? Data()
                    )
                    return .init(
                        chunk: chunk,
                        done: chunk.type == "message_stop"
                    )
                } catch {
                    print("Error decoding chunk: \(error)")
                    throw error
                }
            }

            return .init(chunk: StreamResponse(), done: false)
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
