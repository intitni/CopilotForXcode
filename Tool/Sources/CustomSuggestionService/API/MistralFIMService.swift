import CopilotForXcodeKit
import Foundation
import AIModel
import Logger

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
            var message: OpenAIService.Message?
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
        return try await CompletionHTTP.makeStream(
            result: result,
            response: response,
            mapError: { Error.otherError($0) },
            parseBody: { try Self.parseBody($0, url: url) },
            parseLine: Self.parseStreamLine
        )
    }

    static func parseBody(_ text: String, url: URL) throws -> StreamDataChunk {
        if let message = APIErrorPayload.message(in: text) {
            throw Error.otherError(message)
        }
        do {
            var chunk = try JSONDecoder().decode(StreamDataChunk.self, from: Data(text.utf8))
            if let choice = chunk.choices?.first,
               choice.delta?.content == nil,
               choice.text == nil,
               let content = choice.message?.content
            {
                chunk.choices = [
                    .init(
                        index: choice.index,
                        delta: .init(role: choice.message?.role, content: content),
                        text: content,
                        finish_reason: choice.finish_reason ?? "stop",
                        message: choice.message
                    ),
                ]
            }
            return chunk
        } catch let error as Error {
            throw error
        } catch {
            throw Error.otherError(CompletionHTTP.parseFailureMessage(url: url))
        }
    }

    static func parseStreamLine(_ line: String) throws -> ResponseStream<StreamDataChunk>.LineContent {
        guard let payload = SSELine.payload(of: line) else {
            return .init(chunk: nil, done: false)
        }
        if payload == "[DONE]" { return .init(chunk: nil, done: true) }
        do {
            let chunk = try JSONDecoder().decode(StreamDataChunk.self, from: Data(payload.utf8))
            return .init(chunk: chunk, done: chunk.choices?.first?.finish_reason != nil)
        } catch {
            Logger.service.error(error)
            throw error
        }
    }
}

