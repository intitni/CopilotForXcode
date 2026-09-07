import AIModel
import CopilotForXcodeKit
import Foundation

/// `POST /v1/responses`
///
/// https://platform.openai.com/docs/api-reference/responses/create
public actor OpenAIResponsesService {
    let url: URL
    let modelName: String
    let contextWindow: Int
    let maxToken: Int
    let apiKey: String
    let stopWords: [String]
    let reasoningEffort: ReasoningEffort?
    let extraHeaders: [(name: String, value: String)]

    init(
        url: String? = nil,
        modelName: String,
        contextWindow: Int,
        maxToken: Int,
        stopWords: [String] = [],
        apiKey: String,
        reasoningEffort: ReasoningEffort? = nil,
        extraHeaders: [(name: String, value: String)] = []
    ) {
        self.url = url.flatMap(URL.init(string:))
            ?? URL(string: "https://api.openai.com/v1/responses")!
        self.modelName = modelName
        self.contextWindow = contextWindow
        self.maxToken = maxToken
        self.apiKey = apiKey
        self.stopWords = stopWords
        self.reasoningEffort = reasoningEffort
        self.extraHeaders = extraHeaders
    }
}

extension OpenAIResponsesService: CodeCompletionServiceType {
    typealias CompletionSequence = AsyncThrowingCompactMapSequence<
        ResponseStream<StreamChunk>,
        String
    >

    func getCompletion(_ request: PromptStrategy) async throws -> CompletionSequence {
        let (instructions, input) = createInput(from: request)
        CodeCompletionLogger.logger.logPrompt(
            [(instructions, "instructions")] + input.map {
                ($0.content.map(\.text).joined(), $0.role)
            }
        )
        let result = try await send(instructions: instructions, input: input)
        return result.compactMap { $0.text }
    }
}

// MARK: - Request

extension OpenAIResponsesService {
    struct ContentPart: Encodable {
        var type: String
        var text: String
    }

    struct InputItem: Encodable {
        var role: String
        var content: [ContentPart]
    }

    struct RequestBody: Encodable {
        struct Reasoning: Encodable {
            var effort: String
        }

        var model: String
        var input: [InputItem]
        var instructions: String?
        var stream: Bool
        var max_output_tokens: Int
        var reasoning: Reasoning?
    }

    func createInput(from request: PromptStrategy) -> (instructions: String, input: [InputItem]) {
        let strategy = DefaultTruncateStrategy(maxTokenLimit: max(
            contextWindow / 3 * 2,
            contextWindow - maxToken - 20
        ))
        let prompts = strategy.createTruncatedPrompt(promptStrategy: request)
        let input = prompts.map { prompt -> InputItem in
            switch prompt.role {
            case .user:
                return .init(role: "user", content: [.init(type: "input_text", text: prompt.content)])
            case .assistant:
                return .init(
                    role: "assistant",
                    content: [.init(type: "output_text", text: prompt.content)]
                )
            }
        }
        return (request.systemPrompt, input)
    }

    func send(instructions: String, input: [InputItem]) async throws -> ResponseStream<StreamChunk> {
        let requestBody = RequestBody(
            model: modelName,
            input: input,
            instructions: instructions.isEmpty ? nil : instructions,
            stream: true,
            max_output_tokens: maxToken,
            reasoning: reasoningEffort.map { .init(effort: $0.rawValue) }
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = try JSONEncoder().encode(requestBody)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setExtraHeaders(extraHeaders)
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

        return ResponseStream(result: result, lineExtractor: Self.parseStreamLine)
    }
}

// MARK: - Response

extension OpenAIResponsesService {
    /// A text fragment extracted from one stream line.
    struct StreamChunk {
        var text: String?
    }

    struct APIError: Decodable {
        var message: String?
        var code: String?
    }

    struct OutputContent: Decodable {
        var type: String?
        var text: String?
    }

    struct OutputItem: Decodable {
        var type: String?
        var content: [OutputContent]?
    }

    struct ResponseObject: Decodable {
        var object: String?
        var status: String?
        var output: [OutputItem]?
        var error: APIError?

        var outputText: String {
            (output ?? [])
                .filter { $0.type == "message" }
                .flatMap { $0.content ?? [] }
                .filter { $0.type == "output_text" }
                .compactMap(\.text)
                .joined()
        }
    }

    /// Decodes both a stream event and a bare (non-streaming) response object.
    struct StreamEvent: Decodable {
        var type: String?
        var delta: String?
        var message: String?
        var error: APIError?
        var response: ResponseObject?
        // Fields of a bare response object.
        var object: String?
        var output: [OutputItem]?
    }

    enum Error: Swift.Error, LocalizedError {
        case apiError(String)
        case otherError(String)

        var errorDescription: String? {
            switch self {
            case let .apiError(message), let .otherError(message):
                return message
            }
        }
    }

    /// Parses one line of the event stream, or a whole non-streaming JSON body.
    static func parseStreamLine(_ line: String) throws -> ResponseStream<StreamChunk>.LineContent {
        guard let payload = SSELine.payload(of: line) else { return .init(chunk: nil, done: false) }
        if payload == "[DONE]" { return .init(chunk: nil, done: true) }
        let event = try JSONDecoder().decode(StreamEvent.self, from: Data(payload.utf8))
        switch event.type {
        case "response.output_text.delta":
            return .init(chunk: .init(text: event.delta), done: false)
        case "response.completed", "response.incomplete":
            return .init(chunk: nil, done: true)
        case "response.failed":
            throw Error.apiError(event.response?.error?.message ?? "The response failed.")
        case "error":
            throw Error.apiError(event.error?.message ?? event.message ?? "Unknown error.")
        case .none where event.object == "response":
            let body = ResponseObject(object: event.object, status: nil, output: event.output, error: nil)
            return .init(chunk: .init(text: body.outputText), done: true)
        default:
            return .init(chunk: nil, done: false)
        }
    }
}
