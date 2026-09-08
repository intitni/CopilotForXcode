import Foundation
import AIModel
import GoogleGenerativeAI

public struct GoogleGeminiService {
    let modelName: String
    let maxToken: Int
    let contextWindow: Int
    let temperature: Double
    let stopWords: [String]
    let apiKey: String
    let baseURL: String
    let apiVersion: String

    init(
        modelName: String,
        contextWindow: Int,
        maxToken: Int,
        temperature: Double = 0.2,
        stopWords: [String] = [],
        apiKey: String,
        baseURL: String = "",
        apiVersion: String = ""
    ) {
        self.modelName = modelName
        self.maxToken = maxToken
        self.contextWindow = contextWindow
        self.temperature = temperature
        self.stopWords = stopWords
        self.apiKey = apiKey
        self.baseURL = baseURL
        self.apiVersion = apiVersion
    }
}

extension GoogleGeminiService: CodeCompletionServiceType {
    func getCompletion(_ request: PromptStrategy) async throws -> AsyncThrowingStream<String, Swift.Error> {
        let messages = createMessages(from: request)
        CodeCompletionLogger.logger.logPrompt(messages.map {
            ($0.parts.first?.text ?? "N/A", $0.role ?? "N/A")
        })
        return AsyncThrowingStream<String, Swift.Error> { continuation in
            let task = Task {
                do {
                    let result = try await sendMessages(messages)
                    try Task.checkCancellation()
                    continuation.yield(result)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
}

extension GoogleGeminiService {
    public enum Error: Swift.Error, LocalizedError {
        case apiError(Swift.Error)
        case otherError(Swift.Error)

        public var errorDescription: String? {
            switch self {
            case let .apiError(error):
                return "API error: \(error.localizedDescription)"
            case let .otherError(error):
                return "Error: \(error.localizedDescription)"
            }
        }
    }

    func createMessages(from request: PromptStrategy) -> [ModelContent] {
        let strategy = DefaultTruncateStrategy(maxTokenLimit: max(
            contextWindow / 3 * 2,
            contextWindow - maxToken - 20
        ))
        let prompts = strategy.createTruncatedPrompt(promptStrategy: request)
        return [
            .init(
                role: "user",
                parts: ([request.systemPrompt] + prompts.map(\.content)).joined(separator: "\n\n")
            ),
        ]
    }

    func sendMessages(_ messages: [ModelContent]) async throws -> String {
        let aiModel = GenerativeModel(
            name: modelName,
            apiKey: apiKey,
            generationConfig: .init(GenerationConfig(
                temperature: Float(temperature),
                maxOutputTokens: maxToken,
                stopSequences: stopWords
            )),
            baseURL: baseURL,
            requestOptions: apiVersion.isEmpty
                ? .init()
                : .init(apiVersion: apiVersion)
        )

        do {
            let response = try await aiModel.generateContent(messages)

            return response.candidates.first.map {
                $0.content.parts.first(where: { part in
                    if let text = part.text {
                        return !text.isEmpty
                    } else {
                        return false
                    }
                })?.text ?? ""
            } ?? ""
        } catch let error as GenerateContentError {
            switch error {
            case let .internalError(underlying):
                throw Error.apiError(underlying)
            default:
                throw Error.apiError(error)
            }
        } catch {
            throw Error.otherError(error)
        }
    }
}

