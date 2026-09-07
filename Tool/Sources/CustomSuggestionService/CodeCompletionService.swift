import Foundation
import AIModel
import Keychain
import Preferences

protocol CodeCompletionServiceType {
    associatedtype CompletionSequence: AsyncSequence where CompletionSequence.Element == String

    func getCompletion(_ request: PromptStrategy) async throws -> CompletionSequence
}

extension CodeCompletionServiceType {
    func getCompletions(
        _ request: PromptStrategy,
        streamStopStrategy: StreamStopStrategy,
        count: Int
    ) async throws -> [String] {
        try await withThrowingTaskGroup(of: String.self) { group in
            for _ in 0..<max(1, count) {
                _ = group.addTaskUnlessCancelled {
                    let limiter = StreamLineLimiter(strategy: streamStopStrategy)
                    let stream = try await getCompletion(request)
                    for try await response in stream {
                        if case let .finish(result) = limiter.push(response) {
                            return result
                        }
                    }
                    return limiter.result
                }
            }

            var result = [String]()
            do {
                for try await case let response in group {
                    try Task.checkCancellation()
                    result.append(response)
                    CodeCompletionLogger.logger.logResponse(response)
                }
            } catch {
                group.cancelAll()
                if result.isEmpty {
                    throw error
                }
            }

            return result.filter { !$0.isEmpty }
        }
    }
}

public struct CodeCompletionService {
    public init() {}

    public enum Error: Swift.Error {
        case unknownFormat
    }

    public func getCompletions(
        _ prompt: PromptStrategy,
        streamStopStrategy: StreamStopStrategy,
        model: TabbyModel,
        count: Int
    ) async throws -> [String] {
        let apiKey = apiKey(from: model)

        let service = TabbyService(url: model.url, authorizationMode: {
            switch model.authorizationMode {
            case .none:
                return .none
            case .bearerToken:
                return .bearerToken(apiKey)
            case .basic:
                return .basic(username: model.username, password: apiKey)
            case .customHeaderField:
                return .customHeaderField(name: model.authorizationHeaderName, value: apiKey)
            }
        }())

        let result = try await service.getCompletions(
            prompt,
            streamStopStrategy: streamStopStrategy,
            count: count
        )
        try Task.checkCancellation()
        return result
    }

    public func getCompletions(
        _ prompt: PromptStrategy,
        streamStopStrategy: StreamStopStrategy,
        model: ChatModel,
        count: Int
    ) async throws -> [String] {
        let apiKey = apiKey(from: model)

        switch model.format {
        case .openAI, .openAICompatible:
            let service = OpenAIService(
                url: model.endpoint,
                endpoint: .chatCompletion,
                modelName: model.info.modelName,
                contextWindow: model.info.maxTokens,
                maxToken: UserDefaults.shared.value(for: \.customSuggestionMaxGenerationToken),
                stopWords: prompt.stopWords,
                apiKey: apiKey
            )
            let result = try await service.getCompletions(
                prompt,
                streamStopStrategy: streamStopStrategy,
                count: count
            )
            try Task.checkCancellation()
            return result
        case .azureOpenAI:
            let service = AzureOpenAIService(
                url: model.endpoint,
                endpoint: .chatCompletion,
                modelName: model.info.modelName,
                contextWindow: model.info.maxTokens,
                maxToken: UserDefaults.shared.value(for: \.customSuggestionMaxGenerationToken),
                stopWords: prompt.stopWords,
                apiKey: apiKey
            )
            let result = try await service.getCompletions(
                prompt,
                streamStopStrategy: streamStopStrategy,
                count: count
            )
            try Task.checkCancellation()
            return result
        case .googleAI:
            let service = GoogleGeminiService(
                modelName: model.info.modelName,
                contextWindow: model.info.maxTokens,
                maxToken: UserDefaults.shared.value(for: \.customSuggestionMaxGenerationToken),
                apiKey: apiKey
            )
            let result = try await service.getCompletions(
                prompt,
                streamStopStrategy: streamStopStrategy,
                count: count
            )
            try Task.checkCancellation()
            return result
        case .ollama:
            let service = OllamaService(
                url: model.endpoint,
                endpoint: .chatCompletion,
                modelName: model.info.modelName,
                contextWindow: model.info.maxTokens,
                maxToken: UserDefaults.shared.value(for: \.customSuggestionMaxGenerationToken),
                stopWords: prompt.stopWords,
                keepAlive: model.info.ollamaInfo.keepAlive,
                format: .none
            )
            let result = try await service.getCompletions(
                prompt,
                streamStopStrategy: streamStopStrategy,
                count: count
            )
            try Task.checkCancellation()
            return result
        case .claude:
            let service = AnthropicService(
                url: model.endpoint,
                modelName: model.info.modelName,
                contextWindow: model.info.maxTokens,
                maxToken: UserDefaults.shared.value(for: \.customSuggestionMaxGenerationToken),
                stopWords: prompt.stopWords,
                apiKey: apiKey
            )
            let result = try await service.getCompletions(
                prompt,
                streamStopStrategy: streamStopStrategy,
                count: count
            )
            try Task.checkCancellation()
            return result
        case .gitHubCopilot:
            throw Error.unknownFormat
        }
    }

    public func getCompletions(
        _ prompt: PromptStrategy,
        streamStopStrategy: StreamStopStrategy,
        model: CompletionModel,
        count: Int
    ) async throws -> [String] {
        let apiKey = apiKey(from: model)

        switch model.format {
        case .openAI, .openAICompatible:
            let service = OpenAIService(
                url: model.endpoint,
                endpoint: .completion,
                modelName: model.info.modelName,
                contextWindow: model.info.maxTokens,
                maxToken: UserDefaults.shared.value(for: \.customSuggestionMaxGenerationToken),
                stopWords: prompt.stopWords,
                apiKey: apiKey
            )
            let result = try await service.getCompletions(
                prompt,
                streamStopStrategy: streamStopStrategy,
                count: count
            )
            try Task.checkCancellation()
            return result
        case .azureOpenAI:
            let service = AzureOpenAIService(
                url: model.endpoint,
                endpoint: .completion,
                modelName: model.info.modelName,
                contextWindow: model.info.maxTokens,
                maxToken: UserDefaults.shared.value(for: \.customSuggestionMaxGenerationToken),
                stopWords: prompt.stopWords,
                apiKey: apiKey
            )
            let result = try await service.getCompletions(
                prompt,
                streamStopStrategy: streamStopStrategy,
                count: count
            )
            try Task.checkCancellation()
            return result
        case .ollama:
            let service = OllamaService(
                url: model.endpoint,
                endpoint: .completion,
                modelName: model.info.modelName,
                contextWindow: model.info.maxTokens,
                maxToken: UserDefaults.shared.value(for: \.customSuggestionMaxGenerationToken),
                stopWords: prompt.stopWords,
                keepAlive: model.info.ollamaInfo.keepAlive,
                format: .none
            )
            let result = try await service.getCompletions(
                prompt,
                streamStopStrategy: streamStopStrategy,
                count: count
            )
            try Task.checkCancellation()
            return result
        case .unknown:
            throw Error.unknownFormat
        }
    }

    public func getCompletions(
        _ prompt: PromptStrategy,
        streamStopStrategy: StreamStopStrategy,
        model: FIMModel,
        count: Int
    ) async throws -> [String] {
        let apiKey = apiKey(from: model)

        switch model.format {
        case .mistral:
            let service = MistralFIMService(
                url: URL(string: model.endpoint),
                model: model.info.modelName,
                temperature: 0,
                stopWords: prompt.stopWords,
                apiKey: apiKey,
                contextWindow: model.info.maxTokens,
                maxToken: UserDefaults.shared.value(for: \.customSuggestionMaxGenerationToken)
            )
            let result = try await service.getCompletions(
                prompt,
                streamStopStrategy: streamStopStrategy,
                count: count
            )
            try Task.checkCancellation()
            return result
        case .ollama:
            let service = OllamaService(
                url: model.endpoint,
                endpoint: .completionWithSuffix,
                modelName: model.info.modelName,
                contextWindow: model.info.maxTokens,
                maxToken: UserDefaults.shared.value(for: \.customSuggestionMaxGenerationToken),
                stopWords: prompt.stopWords,
                keepAlive: model.info.ollamaInfo.keepAlive,
                format: .none
            )
            let result = try await service.getCompletions(
                prompt,
                streamStopStrategy: streamStopStrategy,
                count: count
            )
            try Task.checkCancellation()
            return result
        case .ollamaCompatible:
            let service = OllamaService(
                url: model.endpoint,
                endpoint: .completionWithSuffix,
                modelName: model.info.modelName,
                contextWindow: model.info.maxTokens,
                maxToken: UserDefaults.shared.value(for: \.customSuggestionMaxGenerationToken),
                stopWords: prompt.stopWords,
                keepAlive: model.info.ollamaInfo.keepAlive,
                format: .none,
                authenticationMode: {
                    switch model.info.authenticationMode {
                    case .header:
                        return .header(
                            name: model.info.authenticationHeaderFieldName,
                            value: apiKey
                        )
                    case .bearerToken:
                        return .bearerToken(apiKey)
                    }
                }()
            )
            let result = try await service.getCompletions(
                prompt,
                streamStopStrategy: streamStopStrategy,
                count: count
            )
            try Task.checkCancellation()
            return result
        case .unknown:
            throw Error.unknownFormat
        }
    }

    func apiKey(from model: ChatModel) -> String {
        let name = model.info.apiKeyName
        return (try? Keychain.apiKey.get(name)) ?? ""
    }

    func apiKey(from model: CompletionModel) -> String {
        let name = model.info.apiKeyName
        return (try? Keychain.apiKey.get(name)) ?? ""
    }

    func apiKey(from model: TabbyModel) -> String {
        let name = model.apiKeyName
        return (try? Keychain.apiKey.get(name)) ?? ""
    }

    func apiKey(from model: FIMModel) -> String {
        let name = model.info.apiKeyName
        return (try? Keychain.apiKey.get(name)) ?? ""
    }
}

