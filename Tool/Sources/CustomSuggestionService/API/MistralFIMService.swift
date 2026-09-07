import CopilotForXcodeKit
import Foundation
import AIModel

public actor MistralFIMService {
    let url: URL
    let model: String
    let temperature: Double
    let stopWords: [String]
    let apiKey: String
    let contextWindow: Int
    let maxToken: Int

    init(
        url: URL? = nil,
        model: String,
        temperature: Double,
        stopWords: [String] = [],
        apiKey: String,
        contextWindow: Int,
        maxToken: Int
    ) {
        self.url = url ?? URL(string: "https://api.mistral.ai/v1/fim/completions")!
        self.model = model
        self.temperature = temperature
        self.stopWords = stopWords
        self.apiKey = apiKey
        self.contextWindow = contextWindow
        self.maxToken = maxToken
    }
}

extension MistralFIMService: CodeCompletionServiceType {
    typealias CompletionSequence = AsyncThrowingCompactMapSequence<
        ResponseStream<MistralFIMService.StreamDataChunk>,
        String
    >
    
    func getCompletion(_ request: any PromptStrategy) async throws -> CompletionSequence {
        let result = try await send(request)
        return result.compactMap { $0.choices?.first?.delta?.content ?? $0.choices?.first?.text }
    }
}

extension MistralFIMService {
    struct RequestBody: Codable {
        let model: String
        let prompt: String
        let suffix: String
        let stream: Bool
        let temperature: Double
        let max_tokens: Int
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
    
    struct StreamDataChunk: Decodable {
        struct Delta: Decodable {
            var role: OpenAIService.Message.Role?
            var content: String?
        }
        
        struct Choice: Decodable {
            var index: Int
            var delta: Delta?
            var text: String?
            var finish_reason: String?
        }

        var id: String?
        var object: String?
        var model: String?
        var choices: [Choice]?
    }

    func send(_ request: any PromptStrategy) async throws -> ResponseStream<StreamDataChunk> {
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
        
        var request = URLRequest(url: url)
        let requestBody = RequestBody(
            model: model,
            prompt: prefix,
            suffix: suffix,
            stream: true,
            temperature: temperature,
            max_tokens: maxToken
        )
        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(requestBody)
        request.httpMethod = "POST"
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
                    StreamDataChunk.self,
                    from: text.data(using: .utf8) ?? Data()
                )
                return .init(chunk: chunk, done: chunk.choices?.first?.finish_reason != nil)
            } catch {
                print(error)
                throw error
            }
        }
    }
}

