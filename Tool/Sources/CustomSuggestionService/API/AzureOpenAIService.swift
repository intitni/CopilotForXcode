import CopilotForXcodeKit
import Foundation
import AIModel

public actor AzureOpenAIService {
    let url: URL
    let endpoint: OpenAIService.Endpoint
    let modelName: String
    let contextWindow: Int
    let maxToken: Int
    let temperature: Double
    let apiKey: String
    let stopWords: [String]

    init(
        url: String? = nil,
        endpoint: OpenAIService.Endpoint,
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
        self.contextWindow = contextWindow
        self.temperature = temperature
        self.stopWords = stopWords
        self.apiKey = apiKey
    }
}

extension AzureOpenAIService: CodeCompletionServiceType {
    typealias CompletionSequence = AsyncThrowingCompactMapSequence<
        ResponseStream<OpenAIService.ChatCompletionsStreamDataChunk>,
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

extension AzureOpenAIService {
    public typealias Message = OpenAIService.Message
    public typealias APIError = OpenAIService.APIError
    public typealias Error = OpenAIService.Error

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
    ) async throws -> ResponseStream<OpenAIService.ChatCompletionsStreamDataChunk> {
        let requestBody = OpenAIService.ChatCompletionRequestBody(
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
        request.setValue(apiKey, forHTTPHeaderField: "api-key")
        let (result, response) = try await URLSession.shared.bytes(for: request)
        return try await CompletionHTTP.makeStream(
            result: result,
            response: response,
            mapError: { Error.otherError($0) },
            parseBody: { try OpenAIService.parseChatCompletionsBody($0, url: url) },
            parseLine: OpenAIService.parseChatCompletionsStreamLine
        )
    }

    func createPrompt(from request: PromptStrategy) -> String {
        let strategy = DefaultTruncateStrategy(maxTokenLimit: max(
            contextWindow / 3 * 2,
            contextWindow - maxToken - 20
        ))
        let prompts = strategy.createTruncatedPrompt(promptStrategy: request)
        return ([request.systemPrompt] + prompts.map(\.content)).joined(separator: "\n\n")
    }

    func sendPrompt(
        _ prompt: String
    ) async throws -> ResponseStream<OpenAIService.ChatCompletionsStreamDataChunk> {
        let requestBody = OpenAIService.CompletionRequestBody(
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
        request.setValue(apiKey, forHTTPHeaderField: "api-key")
        let (result, response) = try await URLSession.shared.bytes(for: request)
        return try await CompletionHTTP.makeStream(
            result: result,
            response: response,
            mapError: { Error.otherError($0) },
            parseBody: { try OpenAIService.asChatChunk(OpenAIService.parseCompletionsBody($0, url: url)) },
            parseLine: { line in
                let content = try OpenAIService.parseCompletionsStreamLine(line)
                return .init(chunk: content.chunk.map(OpenAIService.asChatChunk), done: content.done)
            }
        )
    }

    func countToken(_ message: Message) -> Int {
        message.content.count
    }
}

