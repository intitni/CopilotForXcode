import AsyncAlgorithms
import Foundation
import GPTEncoder
import Preferences

public protocol ChatGPTServiceType: ObservableObject {
    var history: [ChatMessage] { get async }
    func send(content: String, summary: String?) async throws -> AsyncThrowingStream<String, Error>
    func stopReceivingMessage() async
    func clearHistory() async
    func mutateSystemPrompt(_ newPrompt: String) async
    func mutateHistory(_ mutate: (inout [ChatMessage]) -> Void) async
}

public enum ChatGPTServiceError: Error, LocalizedError {
    case endpointIncorrect
    case responseInvalid
    case otherError(String)

    public var errorDescription: String? {
        switch self {
        case .endpointIncorrect:
            return "ChatGPT endpoint is incorrect"
        case .responseInvalid:
            return "Response is invalid"
        case let .otherError(content):
            return content
        }
    }
}

public struct ChatGPTError: Error, Codable, LocalizedError {
    public var error: ErrorContent
    public init(error: ErrorContent) {
        self.error = error
    }

    public struct ErrorContent: Codable {
        public var message: String
        public var type: String
        public var param: String?
        public var code: String?

        public init(message: String, type: String, param: String? = nil, code: String? = nil) {
            self.message = message
            self.type = type
            self.param = param
            self.code = code
        }
    }

    public var errorDescription: String? {
        error.message
    }
}

public actor ChatGPTService: ChatGPTServiceType {
    public var systemPrompt: String
    public var history: [ChatMessage] = [] {
        didSet { objectWillChange.send() }
    }

    public var configuration: ChatGPTConfiguration

    var uuidGenerator: () -> String = { UUID().uuidString }
    var cancelTask: Cancellable?
    var buildCompletionStreamAPI: CompletionStreamAPIBuilder = OpenAICompletionStreamAPI.init
    var buildCompletionAPI: CompletionAPIBuilder = OpenAICompletionAPI.init

    public init(
        systemPrompt: String = "",
        configuration: ChatGPTConfiguration = UserPreferenceChatGPTConfiguration()
    ) {
        self.systemPrompt = systemPrompt
        self.configuration = configuration
    }

    public func send(
        content: String,
        summary: String? = nil
    ) async throws -> AsyncThrowingStream<String, Error> {
        guard let url = URL(string: configuration.endpoint)
        else { throw ChatGPTServiceError.endpointIncorrect }

        if !content.isEmpty || summary != nil {
            let newMessage = ChatMessage(
                id: uuidGenerator(),
                role: .user,
                content: content,
                summary: summary
            )
            history.append(newMessage)
        }

        let (messages, remainingTokens) = combineHistoryWithSystemPrompt()

        let requestBody = CompletionRequestBody(
            model: configuration.model,
            messages: messages,
            temperature: configuration.temperature,
            stream: true,
            stop: configuration.stop.isEmpty ? nil : configuration.stop,
            max_tokens: maxTokenForReply(
                model: configuration.model,
                remainingTokens: remainingTokens
            )
        )

        let api = buildCompletionStreamAPI(
            configuration.apiKey,
            configuration.featureProvider,
            url,
            requestBody
        )

        return AsyncThrowingStream<String, Error> { continuation in
            Task {
                do {
                    let (trunks, cancel) = try await api()
                    cancelTask = cancel
                    for try await trunk in trunks {
                        guard let delta = trunk.choices.first?.delta else { continue }

                        if history.last?.id == trunk.id {
                            if let role = delta.role {
                                history[history.endIndex - 1].role = role
                            }
                            if let content = delta.content {
                                history[history.endIndex - 1].content.append(content)
                            }
                        } else {
                            history.append(.init(
                                id: trunk.id,
                                role: delta.role ?? .assistant,
                                content: delta.content ?? ""
                            ))
                        }

                        if let content = delta.content {
                            continuation.yield(content)
                        }

                        try await Task.sleep(nanoseconds: 3_500_000)
                    }

                    continuation.finish()
                } catch let error as CancellationError {
                    continuation.finish(throwing: error)
                } catch let error as NSError where error.code == NSURLErrorCancelled {
                    continuation.finish(throwing: error)
                } catch {
                    history.append(.init(
                        role: .assistant,
                        content: error.localizedDescription
                    ))
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    public func sendAndWait(
        content: String,
        summary: String? = nil
    ) async throws -> String? {
        guard let url = URL(string: configuration.endpoint) else { throw ChatGPTServiceError.endpointIncorrect }

        if !content.isEmpty || summary != nil {
            let newMessage = ChatMessage(
                id: uuidGenerator(),
                role: .user,
                content: content,
                summary: summary
            )
            history.append(newMessage)
        }

        let (messages, remainingTokens) = combineHistoryWithSystemPrompt()

        let requestBody = CompletionRequestBody(
            model: configuration.model,
            messages: messages,
            temperature: configuration.temperature,
            stream: true,
            stop: configuration.stop.isEmpty ? nil : configuration.stop,
            max_tokens: maxTokenForReply(model: configuration.model, remainingTokens: remainingTokens)
        )

        let api = buildCompletionAPI(
            configuration.apiKey,
            configuration.featureProvider,
            url,
            requestBody
        )
        let response = try await api()

        if let choice = response.choices.first {
            history.append(.init(
                id: response.id,
                role: choice.message.role,
                content: choice.message.content
            ))

            return choice.message.content
        }

        return nil
    }

    public func stopReceivingMessage() {
        cancelTask?()
        cancelTask = nil
    }

    public func clearHistory() {
        stopReceivingMessage()
        history = []
    }

    public func mutateSystemPrompt(_ newPrompt: String) {
        systemPrompt = newPrompt
    }

    public func mutateHistory(_ mutate: (inout [ChatMessage]) -> Void) async {
        mutate(&history)
    }
}

extension ChatGPTService {
    func changeBuildCompletionStreamAPI(_ builder: @escaping CompletionStreamAPIBuilder) {
        buildCompletionStreamAPI = builder
    }

    func changeUUIDGenerator(_ generator: @escaping () -> String) {
        uuidGenerator = generator
    }

    func combineHistoryWithSystemPrompt(
        minimumReplyTokens: Int = 300,
        maxNumberOfMessages: Int = UserDefaults.shared.value(for: \.chatGPTMaxMessageCount),
        maxTokens: Int = UserDefaults.shared.value(for: \.chatGPTMaxToken),
        encoder: TokenEncoder = GPTEncoder()
    )
        -> (messages: [CompletionRequestBody.Message], remainingTokens: Int)
    {
        var all: [CompletionRequestBody.Message] = []
        var allTokensCount = encoder.encode(text: systemPrompt).count
        for (index, message) in history.enumerated().reversed() {
            if maxNumberOfMessages > 0, all.count >= maxNumberOfMessages { break }
            if message.content.isEmpty { continue }
            let tokensCount = message.tokensCount ?? encoder.encode(text: message.content).count
            history[index].tokensCount = tokensCount
            if tokensCount + allTokensCount > maxTokens - minimumReplyTokens {
                break
            }
            allTokensCount += tokensCount
            all.append(.init(role: message.role, content: message.content))
        }

        if !systemPrompt.isEmpty {
            all.append(.init(role: .system, content: systemPrompt))
        }
        return (all.reversed(), max(minimumReplyTokens, maxTokens - allTokensCount))
    }
}

protocol TokenEncoder {
    func encode(text: String) -> [Int]
}

extension GPTEncoder: TokenEncoder {}

func maxTokenForReply(model: String, remainingTokens: Int) -> Int {
    guard let model = ChatGPTModel(rawValue: model) else { return remainingTokens }
    return min(model.maxToken / 2, remainingTokens)
}

