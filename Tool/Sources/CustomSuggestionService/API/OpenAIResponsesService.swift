import AIModel
import CopilotForXcodeKit
import Foundation
import Logger
import Preferences

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
    let reasoningTokenBudget: Int
    let extraHeaders: [(name: String, value: String)]
    let organizationID: String
    let projectID: String
    let customJSONBody: String
    let requiresBeginWithUserMessage: Bool
    let enforceMessageOrder: Bool

    init(
        url: String? = nil,
        modelName: String,
        contextWindow: Int,
        maxToken: Int,
        stopWords: [String] = [],
        apiKey: String,
        reasoningEffort: ReasoningEffort? = nil,
        reasoningTokenBudget: Int = 1500,
        extraHeaders: [(name: String, value: String)] = [],
        organizationID: String = "",
        projectID: String = "",
        customJSONBody: String = "",
        requiresBeginWithUserMessage: Bool = false,
        enforceMessageOrder: Bool = false
    ) {
        self.url = url.flatMap(URL.init(string:))
            ?? URL(string: "https://api.openai.com/v1/responses")!
        self.modelName = modelName
        self.contextWindow = contextWindow
        self.maxToken = maxToken
        self.apiKey = apiKey
        self.stopWords = stopWords
        self.reasoningEffort = reasoningEffort
        self.reasoningTokenBudget = reasoningTokenBudget
        self.extraHeaders = extraHeaders
        self.organizationID = organizationID
        self.projectID = projectID
        self.customJSONBody = customJSONBody
        self.requiresBeginWithUserMessage = requiresBeginWithUserMessage
        self.enforceMessageOrder = enforceMessageOrder
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
        var store: Bool
        var temperature: Double?
        var reasoning: Reasoning?
    }

    nonisolated static func makeRequestBody(
        modelName: String,
        input: [InputItem],
        instructions: String?,
        maxToken: Int,
        reasoningEffort: ReasoningEffort?,
        reasoningTokenBudget: Int
    ) -> RequestBody {
        RequestBody(
            model: modelName,
            input: input,
            instructions: instructions,
            stream: true,
            max_output_tokens: ReasoningTokenLimit.maxOutputTokens(
                maxToken: maxToken,
                effort: reasoningEffort,
                budget: reasoningTokenBudget
            ),
            store: false,
            temperature: reasoningEffort == nil ? 0.2 : nil,
            reasoning: reasoningEffort.map { .init(effort: $0.rawValue) }
        )
    }

    func createInput(from request: PromptStrategy) -> (instructions: String, input: [InputItem]) {
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
        let instructions = ordered.filter { $0.role == .system }.map(\.content)
            .joined(separator: "\n\n")
        let input = ordered.compactMap { message -> InputItem? in
            switch message.role {
            case .system:
                return nil
            case .user:
                return .init(
                    role: "user",
                    content: [.init(type: "input_text", text: message.content)]
                )
            case .assistant:
                return .init(
                    role: "assistant",
                    content: [.init(type: "output_text", text: message.content)]
                )
            }
        }
        return (instructions, input)
    }

    func send(instructions: String, input: [InputItem]) async throws -> ResponseStream<StreamChunk> {
        let requestBody = Self.makeRequestBody(
            modelName: modelName,
            input: input,
            instructions: instructions.isEmpty ? nil : instructions,
            maxToken: maxToken,
            reasoningEffort: reasoningEffort,
            reasoningTokenBudget: reasoningTokenBudget
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = CompletionJSON.mergeCustomBody(
            try JSONEncoder().encode(requestBody),
            jsonBody: customJSONBody
        )
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setOpenAIIdentityHeaders(organizationID: organizationID, projectID: projectID)
        request.setExtraHeaders(extraHeaders)
        let (result, response) = try await URLSession.shared.bytes(for: request)
        return try await CompletionHTTP.makeStream(
            result: result,
            response: response,
            mapError: { Error.otherError($0) },
            parseBody: { try Self.parseNonStreamingBody($0, url: url) },
            parseLine: Self.parseStreamLine
        )
    }

    static func parseNonStreamingBody(_ text: String, url: URL) throws -> StreamChunk {
        if let message = APIErrorPayload.message(in: text) {
            throw Error.apiError(message)
        }
        do {
            let object = try JSONDecoder().decode(ResponseObject.self, from: Data(text.utf8))
            if let message = object.error?.message {
                throw Error.apiError(message)
            }
            return StreamChunk(text: object.outputText)
        } catch let error as Error {
            throw error
        } catch {
            throw Error.otherError(CompletionHTTP.parseFailureMessage(url: url))
        }
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

    struct IncompleteDetails: Decodable {
        var reason: String?
    }

    struct ResponseObject: Decodable {
        var id: String?
        var object: String?
        var status: String?
        var output: [OutputItem]?
        var error: APIError?
        var incomplete_details: IncompleteDetails?

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

    /// Parses one line of the event stream.
    static func parseStreamLine(_ line: String) throws -> ResponseStream<StreamChunk>.LineContent {
        guard let payload = SSELine.payload(of: line) else { return .init(chunk: nil, done: false) }
        if payload == "[DONE]" { return .init(chunk: nil, done: true) }
        if let message = APIErrorPayload.message(in: payload) {
            throw Error.apiError(message)
        }
        let event = try JSONDecoder().decode(StreamEvent.self, from: Data(payload.utf8))
        switch event.type {
        case "response.output_text.delta":
            return .init(chunk: .init(text: event.delta), done: false)
        case "response.completed":
            return .init(chunk: nil, done: true)
        case "response.incomplete":
            if event.response?.incomplete_details?.reason == "max_output_tokens" {
                Logger.service.error(
                    "Completion truncated: incomplete_details.reason=max_output_tokens request_id=\(event.response?.id ?? "unknown")"
                )
            }
            return .init(chunk: nil, done: true)
        case "response.failed":
            throw Error.apiError(event.response?.error?.message ?? "The response failed.")
        case "error":
            throw Error.apiError(event.error?.message ?? event.message ?? "Unknown error.")
        case .none where event.object == "response":
            let body = ResponseObject(
                id: nil,
                object: event.object,
                status: nil,
                output: event.output,
                error: nil,
                incomplete_details: nil
            )
            return .init(chunk: .init(text: body.outputText), done: true)
        default:
            return .init(chunk: nil, done: false)
        }
    }
}
