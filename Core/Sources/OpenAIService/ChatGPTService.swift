import AsyncAlgorithms
import Foundation
import GPTEncoder
import Preferences

public protocol ChatGPTServiceType: ObservableObject {
    var isReceivingMessage: Bool { get async }
    var history: [ChatMessage] { get async }
    func send(content: String, summary: String?) async throws -> AsyncThrowingStream<String, Error>
    func stopReceivingMessage() async
    func clearHistory() async
    func mutateSystemPrompt(_ newPrompt: String) async
    func mutateHistory(_ mutate: (inout [ChatMessage]) -> Void) async
    func markReceivingMessage(_ receiving: Bool) async
}

public enum ChatGPTServiceError: Error, LocalizedError {
    case endpointIncorrect
    case responseInvalid

    public var errorDescription: String? {
        switch self {
        case .endpointIncorrect:
            return "ChatGPT endpoint is incorrect"
        case .responseInvalid:
            return "Response is invalid"
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

    public var defaultTemperature: Double {
        min(max(0, UserDefaults.shared.value(for: \.chatGPTTemperature)), 2)
    }
    
    var temperature: Double?

    public var model: String {
        let value = UserDefaults.shared.value(for: \.chatGPTModel)
        if value.isEmpty { return "gpt-3.5-turbo" }
        return value
    }

    public var endpoint: String {
        let value = UserDefaults.shared.value(for: \.chatGPTEndpoint)
        if value.isEmpty { return "https://api.openai.com/v1/chat/completions" }

        return value
    }

    public var apiKey: String {
        UserDefaults.shared.value(for: \.openAIAPIKey)
    }

    public var maxToken: Int {
        UserDefaults.shared.value(for: \.chatGPTMaxToken)
    }

    public var history: [ChatMessage] = [] {
        didSet { objectWillChange.send() }
    }

    public internal(set) var isReceivingMessage = false {
        didSet { objectWillChange.send() }
    }

    var uuidGenerator: () -> String = { UUID().uuidString }
    var cancelTask: Cancellable?
    var buildCompletionStreamAPI: CompletionStreamAPIBuilder = OpenAICompletionStreamAPI.init
    var buildCompletionAPI: CompletionAPIBuilder = OpenAICompletionAPI.init

    public init(
        systemPrompt: String = "",
        temperature: Double? = nil
    ) {
        self.systemPrompt = systemPrompt
        self.temperature = temperature
    }

    public func send(
        content: String,
        summary: String? = nil
    ) async throws -> AsyncThrowingStream<String, Error> {
        guard !isReceivingMessage else { throw CancellationError() }
        guard let url = URL(string: endpoint) else { throw ChatGPTServiceError.endpointIncorrect }
        let newMessage = ChatMessage(
            id: uuidGenerator(),
            role: .user,
            content: content,
            summary: summary
        )
        history.append(newMessage)

        let (messages, remainingTokens) = combineHistoryWithSystemPrompt()

        let requestBody = CompletionRequestBody(
            model: model,
            messages: messages,
            temperature: temperature ?? defaultTemperature,
            stream: true,
            max_tokens: remainingTokens
        )

        isReceivingMessage = true

        let api = buildCompletionStreamAPI(apiKey, url, requestBody)

        return AsyncThrowingStream<String, Error> { continuation in
            Task {
                do {
                    let (trunks, cancel) = try await api()
                    guard isReceivingMessage else {
                        continuation.finish()
                        return
                    }
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
                    }

                    continuation.finish()
                    isReceivingMessage = false
                } catch let error as CancellationError {
                    isReceivingMessage = false
                    continuation.finish(throwing: error)
                } catch let error as NSError where error.code == NSURLErrorCancelled {
                    isReceivingMessage = false
                    continuation.finish(throwing: error)
                } catch {
                    history.append(.init(
                        role: .assistant,
                        content: error.localizedDescription
                    ))
                    isReceivingMessage = false
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    public func sendAndWait(
        content: String,
        summary: String? = nil
    ) async throws -> String? {
        guard !isReceivingMessage else { throw CancellationError() }
        guard let url = URL(string: endpoint) else { throw ChatGPTServiceError.endpointIncorrect }
        let newMessage = ChatMessage(
            id: uuidGenerator(),
            role: .user,
            content: content,
            summary: summary
        )
        history.append(newMessage)

        let (messages, remainingTokens) = combineHistoryWithSystemPrompt()

        let requestBody = CompletionRequestBody(
            model: model,
            messages: messages,
            temperature: temperature ?? defaultTemperature,
            stream: true,
            max_tokens: remainingTokens
        )

        isReceivingMessage = true
        defer { isReceivingMessage = false }

        let api = buildCompletionAPI(apiKey, url, requestBody)
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
        isReceivingMessage = false
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

    public func markReceivingMessage(_ receiving: Bool) {
        isReceivingMessage = receiving
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
        minimumReplyTokens: Int = 200,
        maxNumberOfMessages: Int = UserDefaults.shared.value(for: \.chatGPTMaxMessageCount),
        maxTokens: Int = UserDefaults.shared.value(for: \.chatGPTMaxToken),
        encoder: TokenEncoder = GPTEncoder()
    )
        -> (messages: [CompletionRequestBody.Message], remainingTokens: Int)
    {
        var all: [CompletionRequestBody.Message] = []
        var allTokensCount = encoder.encode(text: systemPrompt).count
        for message in history.reversed() {
            if maxNumberOfMessages > 0, all.count >= maxNumberOfMessages { break }
            if message.content.isEmpty { continue }
            let tokensCount = encoder.encode(text: message.content).count
            if tokensCount + allTokensCount > maxTokens - minimumReplyTokens {
                break
            }
            allTokensCount += tokensCount
            all.append(.init(role: message.role, content: message.content))
        }

        all.append(.init(role: .system, content: systemPrompt))
        return (all.reversed(), max(minimumReplyTokens, maxTokens - allTokensCount))
    }
}

protocol TokenEncoder {
    func encode(text: String) -> [Int]
}

extension GPTEncoder: TokenEncoder {}
