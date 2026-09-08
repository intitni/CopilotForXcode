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

    /// Streams one completion while it is generated.
    ///
    /// Every element is the whole text received so far, already cut by stop words and the line
    /// limit, minus a trailing fragment that could still turn out to be a stop word. The last
    /// element is exactly what ``getCompletions(_:streamStopStrategy:count:)`` would return.
    func streamCompletion(
        _ request: PromptStrategy,
        streamStopStrategy: StreamStopStrategy
    ) -> AsyncThrowingStream<String, Swift.Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let limiter = StreamLineLimiter(strategy: streamStopStrategy)
                    let stream = try await getCompletion(request)
                    let result = try await feedCompletion(
                        from: stream,
                        stopWords: request.stopWords,
                        limiter: limiter
                    ) { partial in
                        continuation.yield(partial)
                    }
                    try Task.checkCancellation()
                    continuation.yield(result)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}

func collectCompletion<S: AsyncSequence>(
    from stream: S,
    stopWords: [String],
    limiter: StreamLineLimiter
) async throws -> String where S.Element == String {
    try await feedCompletion(from: stream, stopWords: stopWords, limiter: limiter) { _ in }
}

/// Feeds `stream` into `limiter`, reporting the displayable text after every token, and returns
/// the final text: cut at the first stop word, or where the limiter decided to stop.
func feedCompletion<S: AsyncSequence>(
    from stream: S,
    stopWords: [String],
    limiter: StreamLineLimiter,
    onPartial: (String) -> Void
) async throws -> String where S.Element == String {
    for try await response in stream {
        if !response.isEmpty { CodeCompletionLogger.logger.logFirstToken() }
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
        onPartial(CompletionStopWords.displayablePrefix(of: limiter.result, stopWords: stopWords))
    }
    return limiter.result
}

/// Type-erased ``CodeCompletionServiceType`` so the per-model dispatch can serve both the blocking
/// and the streaming entry points. Errors and cancellation pass through unchanged.
struct ErasedCompletionService: CodeCompletionServiceType {
    typealias CompletionSequence = AsyncThrowingStream<String, Swift.Error>

    let makeCompletion: (PromptStrategy) async throws -> CompletionSequence

    init<Service: CodeCompletionServiceType>(_ service: Service) {
        makeCompletion = { request in
            let sequence = try await service.getCompletion(request)
            return AsyncThrowingStream { continuation in
                let task = Task {
                    do {
                        for try await element in sequence {
                            try Task.checkCancellation()
                            continuation.yield(element)
                        }
                        continuation.finish()
                    } catch {
                        continuation.finish(throwing: error)
                    }
                }
                continuation.onTermination = { _ in task.cancel() }
            }
        }
    }

    func getCompletion(_ request: PromptStrategy) async throws -> CompletionSequence {
        try await makeCompletion(request)
    }
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

    // MARK: Blocking

    func getCompletions(
        _ prompt: PromptStrategy,
        streamStopStrategy: StreamStopStrategy,
        model: CustomSuggestionCoordinator.Model,
        count: Int
    ) async throws -> [String] {
        let result = try await completionService(for: model, prompt: prompt).getCompletions(
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
        model: TabbyModel,
        count: Int
    ) async throws -> [String] {
        try await getCompletions(
            prompt,
            streamStopStrategy: streamStopStrategy,
            model: .tabbyModel(model),
            count: count
        )
    }

    public func getCompletions(
        _ prompt: PromptStrategy,
        streamStopStrategy: StreamStopStrategy,
        model: ChatModel,
        count: Int
    ) async throws -> [String] {
        try await getCompletions(
            prompt,
            streamStopStrategy: streamStopStrategy,
            model: .chatModel(model),
            count: count
        )
    }

    public func getCompletions(
        _ prompt: PromptStrategy,
        streamStopStrategy: StreamStopStrategy,
        model: CompletionModel,
        count: Int
    ) async throws -> [String] {
        try await getCompletions(
            prompt,
            streamStopStrategy: streamStopStrategy,
            model: .completionModel(model),
            count: count
        )
    }

    public func getCompletions(
        _ prompt: PromptStrategy,
        streamStopStrategy: StreamStopStrategy,
        model: FIMModel,
        count: Int
    ) async throws -> [String] {
        try await getCompletions(
            prompt,
            streamStopStrategy: streamStopStrategy,
            model: .fimModel(model),
            count: count
        )
    }

    // MARK: Streaming

    /// See ``CodeCompletionServiceType/streamCompletion(_:streamStopStrategy:)``.
    func streamCompletion(
        _ prompt: PromptStrategy,
        streamStopStrategy: StreamStopStrategy,
        model: CustomSuggestionCoordinator.Model
    ) async throws -> AsyncThrowingStream<String, Swift.Error> {
        try await completionService(for: model, prompt: prompt)
            .streamCompletion(prompt, streamStopStrategy: streamStopStrategy)
    }

    // MARK: Per-model dispatch

    func completionService(
        for model: CustomSuggestionCoordinator.Model,
        prompt: PromptStrategy
    ) async throws -> ErasedCompletionService {
        switch model {
        case let .chatModel(model):
            return try await completionService(for: model, prompt: prompt)
        case let .completionModel(model):
            return try completionService(for: model, prompt: prompt)
        case let .tabbyModel(model):
            return completionService(for: model, prompt: prompt)
        case let .fimModel(model):
            return try completionService(for: model, prompt: prompt)
        }
    }

    func completionService(for model: TabbyModel, prompt: PromptStrategy) -> ErasedCompletionService {
        let apiKey = apiKey(from: model)

        return .init(TabbyService(url: model.url, authorizationMode: {
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
        }()))
    }

    func completionService(
        for model: ChatModel,
        prompt: PromptStrategy
    ) async throws -> ErasedCompletionService {
        let apiKey = apiKey(from: model)

        let options = await ChatAPIOptions.current(for: model, apiKey: apiKey)
        CodeCompletionLogger.logger.logEndpoint(model.endpoint)

        switch model.format {
        case .openAI, .openAICompatible:
            switch options.api {
            case .responses:
                let responsesURL = Self.responsesEndpoint(for: model)
                CodeCompletionLogger.logger.logEndpoint(responsesURL)
                return .init(OpenAIResponsesService(
                    url: responsesURL,
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
                ))
            case .chatCompletions:
                return .init(try OpenAIService(
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
                ))
            }
        case .azureOpenAI:
            return .init(try OpenAIService(
                url: model.endpoint,
                endpoint: .chatCompletion,
                modelName: model.info.modelName,
                contextWindow: model.info.maxTokens,
                maxToken: UserDefaults.shared.value(for: \.customSuggestionMaxGenerationToken),
                stopWords: prompt.stopWords,
                apiKey: apiKey,
                authentication: .apiKeyHeader,
                reasoningEffort: options.reasoningEffort,
                reasoningTokenBudget: options.reasoningTokenBudget,
                extraHeaders: options.extraHeaders
            ))
        case .googleAI:
            return .init(GoogleGeminiService(
                modelName: model.info.modelName,
                contextWindow: model.info.maxTokens,
                maxToken: UserDefaults.shared.value(for: \.customSuggestionMaxGenerationToken),
                apiKey: apiKey,
                baseURL: model.endpoint,
                apiVersion: model.info.googleGenerativeAIInfo.apiVersion
            ))
        case .ollama:
            return .init(OllamaService(
                url: model.endpoint,
                endpoint: .chatCompletion,
                modelName: model.info.modelName,
                contextWindow: model.info.maxTokens,
                maxToken: UserDefaults.shared.value(for: \.customSuggestionMaxGenerationToken),
                stopWords: prompt.stopWords,
                keepAlive: model.info.ollamaInfo.keepAlive,
                format: .none,
                extraHeaders: options.extraHeaders
            ))
        case .claude:
            return .init(AnthropicService(
                url: model.endpoint,
                modelName: model.info.modelName,
                contextWindow: model.info.maxTokens,
                maxToken: UserDefaults.shared.value(for: \.customSuggestionMaxGenerationToken),
                stopWords: prompt.stopWords,
                apiKey: apiKey,
                extraHeaders: options.extraHeaders,
                reasoningEffort: options.reasoningEffort,
                customJSONBody: model.info.customBodyInfo.jsonBody
            ))
        case .gitHubCopilot:
            throw Error.gitHubCopilotNotSupported
        }
    }

    func completionService(
        for model: CompletionModel,
        prompt: PromptStrategy
    ) throws -> ErasedCompletionService {
        let apiKey = apiKey(from: model)

        switch model.format {
        case .openAI, .openAICompatible:
            return .init(try OpenAIService(
                url: model.endpoint,
                endpoint: .completion,
                modelName: model.info.modelName,
                contextWindow: model.info.maxTokens,
                maxToken: UserDefaults.shared.value(for: \.customSuggestionMaxGenerationToken),
                stopWords: prompt.stopWords,
                apiKey: apiKey
            ))
        case .azureOpenAI:
            return .init(try OpenAIService(
                url: model.endpoint,
                endpoint: .completion,
                modelName: model.info.modelName,
                contextWindow: model.info.maxTokens,
                maxToken: UserDefaults.shared.value(for: \.customSuggestionMaxGenerationToken),
                stopWords: prompt.stopWords,
                apiKey: apiKey,
                authentication: .apiKeyHeader
            ))
        case .ollama:
            return .init(OllamaService(
                url: model.endpoint,
                endpoint: .completion,
                modelName: model.info.modelName,
                contextWindow: model.info.maxTokens,
                maxToken: UserDefaults.shared.value(for: \.customSuggestionMaxGenerationToken),
                stopWords: prompt.stopWords,
                keepAlive: model.info.ollamaInfo.keepAlive,
                format: .none
            ))
        case .unknown:
            throw Error.unknownFormat
        }
    }

    func completionService(
        for model: FIMModel,
        prompt: PromptStrategy
    ) throws -> ErasedCompletionService {
        let apiKey = apiKey(from: model)

        switch model.format {
        case .mistral:
            return .init(MistralFIMService(
                url: URL(string: model.endpoint),
                model: model.info.modelName,
                temperature: 0,
                stopWords: prompt.stopWords,
                apiKey: apiKey,
                contextWindow: model.info.maxTokens,
                maxToken: UserDefaults.shared.value(for: \.customSuggestionMaxGenerationToken)
            ))
        case .ollama:
            return .init(OllamaService(
                url: model.endpoint,
                endpoint: .completionWithSuffix,
                modelName: model.info.modelName,
                contextWindow: model.info.maxTokens,
                maxToken: UserDefaults.shared.value(for: \.customSuggestionMaxGenerationToken),
                stopWords: prompt.stopWords,
                keepAlive: model.info.ollamaInfo.keepAlive,
                format: .none
            ))
        case .ollamaCompatible:
            return .init(OllamaService(
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
            ))
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

