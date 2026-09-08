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
                    return try await collectCompletion(
                        from: stream,
                        stopWords: request.stopWords,
                        limiter: limiter
                    )
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

func collectCompletion<S: AsyncSequence>(
    from stream: S,
    stopWords: [String],
    limiter: StreamLineLimiter
) async throws -> String where S.Element == String {
    for try await response in stream {
        let push = limiter.push(response)
        if let truncated = CompletionStopWords.truncatedPrefix(
            of: limiter.result,
            stopWords: stopWords
        ) {
            return truncated
        }
        if case let .finish(result) = push {
            return result
        }
    }
    return limiter.result
}

public struct CodeCompletionService {
    public init() {}

    public enum Error: Swift.Error, LocalizedError {
        case unknownFormat
        case gitHubCopilotNotSupported

        public var errorDescription: String? {
            switch self {
            case .unknownFormat:
                return "Unknown model format."
            case .gitHubCopilotNotSupported:
                return "GitHub Copilot chat models can't be used for completion"
            }
        }
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

        let options = await ChatAPIOptions.current(for: model, apiKey: apiKey)

        switch model.format {
        case .openAI, .openAICompatible:
            switch options.api {
            case .responses:
                let service = OpenAIResponsesService(
                    url: Self.responsesEndpoint(for: model),
                    modelName: model.info.modelName,
                    contextWindow: model.info.maxTokens,
                    maxToken: UserDefaults.shared.value(for: \.customSuggestionMaxGenerationToken),
                    stopWords: prompt.stopWords,
                    apiKey: apiKey,
                    reasoningEffort: options.reasoningEffort,
                    reasoningTokenBudget: options.reasoningTokenBudget,
                    extraHeaders: options.extraHeaders,
                    organizationID: model.info.openAIInfo.organizationID,
                    projectID: model.info.openAIInfo.projectID,
                    customJSONBody: model.info.customBodyInfo.jsonBody,
                    requiresBeginWithUserMessage: model.info.openAICompatibleInfo
                        .requiresBeginWithUserMessage,
                    enforceMessageOrder: model.info.openAICompatibleInfo.enforceMessageOrder
                )
                let result = try await service.getCompletions(
                    prompt,
                    streamStopStrategy: streamStopStrategy,
                    count: count
                )
                try Task.checkCancellation()
                return result
            case .chatCompletions:
                let service = OpenAIService(
                    url: model.endpoint,
                    endpoint: .chatCompletion,
                    modelName: model.info.modelName,
                    contextWindow: model.info.maxTokens,
                    maxToken: UserDefaults.shared.value(for: \.customSuggestionMaxGenerationToken),
                    stopWords: prompt.stopWords,
                    apiKey: apiKey,
                    reasoningEffort: options.reasoningEffort,
                    reasoningTokenBudget: options.reasoningTokenBudget,
                    extraHeaders: options.extraHeaders,
                    organizationID: model.info.openAIInfo.organizationID,
                    projectID: model.info.openAIInfo.projectID,
                    customJSONBody: model.info.customBodyInfo.jsonBody,
                    requiresBeginWithUserMessage: model.info.openAICompatibleInfo
                        .requiresBeginWithUserMessage,
                    enforceMessageOrder: model.info.openAICompatibleInfo.enforceMessageOrder
                )
                let result = try await service.getCompletions(
                    prompt,
                    streamStopStrategy: streamStopStrategy,
                    count: count
                )
                try Task.checkCancellation()
                return result
            }
        case .azureOpenAI:
            let service = AzureOpenAIService(
                url: model.endpoint,
                endpoint: .chatCompletion,
                modelName: model.info.modelName,
                contextWindow: model.info.maxTokens,
                maxToken: UserDefaults.shared.value(for: \.customSuggestionMaxGenerationToken),
                stopWords: prompt.stopWords,
                apiKey: apiKey,
                extraHeaders: options.extraHeaders
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
                apiKey: apiKey,
                baseURL: model.endpoint,
                apiVersion: model.info.googleGenerativeAIInfo.apiVersion
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
                format: .none,
                extraHeaders: options.extraHeaders
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
                apiKey: apiKey,
                extraHeaders: options.extraHeaders,
                reasoningEffort: options.reasoningEffort,
                customJSONBody: model.info.customBodyInfo.jsonBody
            )
            let result = try await service.getCompletions(
                prompt,
                streamStopStrategy: streamStopStrategy,
                count: count
            )
            try Task.checkCancellation()
            return result
        case .gitHubCopilot:
            throw Error.gitHubCopilotNotSupported
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

    /// `ChatModel.endpoint` always points at `/v1/chat/completions`; derive the Responses API URL.
    static func responsesEndpoint(for model: ChatModel) -> String {
        let baseURL = model.info.baseURL
        if baseURL.isEmpty { return "https://api.openai.com/v1/responses" }
        if model.format == .openAICompatible, model.info.isFullURL {
            return rewriteChatCompletionsFullURL(baseURL)
        }
        let trimmed = baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL
        return "\(trimmed)/v1/responses"
    }

    /// Full URLs may have a trailing slash or query; match `/chat/completions` on the path only.
    static func rewriteChatCompletionsFullURL(_ baseURL: String) -> String {
        if let url = URL(string: baseURL),
           var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        {
            var path = components.path
            while path.count > 1, path.hasSuffix("/") {
                path.removeLast()
            }
            if path.hasSuffix("/chat/completions") {
                components.path = String(path.dropLast("/chat/completions".count)) + "/responses"
                if let rewritten = components.string {
                    return rewritten
                }
            }
            return baseURL
        }

        let parts = baseURL.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false)
        var head = String(parts[0])
        while head.hasSuffix("/") {
            head.removeLast()
        }
        guard head.hasSuffix("/chat/completions") else { return baseURL }
        head = String(head.dropLast("/chat/completions".count)) + "/responses"
        if parts.count > 1 {
            return head + "?" + parts[1]
        }
        return head
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

