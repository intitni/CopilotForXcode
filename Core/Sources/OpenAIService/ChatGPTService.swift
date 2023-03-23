import AsyncAlgorithms
import Foundation
import Logger

public protocol ChatGPTServiceType {
    func send(content: String, summary: String?) async throws -> AsyncThrowingStream<String, Error>
    func stopReceivingMessage() async
    func restart() async
    func mutateSystemPrompt(_ newPrompt: String) async
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

public actor ChatGPTService: ChatGPTServiceType, ObservableObject {
    public var temperature: Double
    public var model: String
    public var endpoint: String
    public var apiKey: String
    public var systemPrompt: String
    public var maxToken: Int
    public var history: [ChatMessage] = [] {
        didSet { objectWillChange.send() }
    }

    public internal(set) var isReceivingMessage = false
    var cancelTask: Cancellable?
    var buildCompletionStreamAPI: CompletionStreamAPIBuilder = OpenAICompletionStreamAPI.init

    deinit {
        print("deinit")
    }

    public init(
        systemPrompt: String,
        apiKey: String,
        endpoint: String? = nil,
        model: String? = nil,
        temperature: Double = 1,
        maxToken: Int = 2048
    ) {
        self.systemPrompt = systemPrompt
        self.apiKey = apiKey
        self.model = model ?? "gpt-3.5-turbo"
        self.temperature = temperature
        self.maxToken = maxToken
        self.endpoint = endpoint ?? "https://api.openai.com/v1/chat/completions"
    }

    public func send(
        content: String,
        summary: String? = nil
    ) async throws -> AsyncThrowingStream<String, Error> {
        guard !isReceivingMessage else { throw CancellationError() }
        guard let url = URL(string: endpoint) else { throw ChatGPTServiceError.endpointIncorrect }
        let newMessage = ChatMessage(role: .user, content: content, summary: summary)
        history.append(newMessage)

        let requestBody = CompletionRequestBody(
            model: model,
            messages: combineHistoryWithSystemPrompt(),
            temperature: temperature,
            stream: true,
            max_tokens: maxToken
        )

        isReceivingMessage = true

        do {
            let api = buildCompletionStreamAPI(apiKey, url, requestBody)

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
                        }

                        continuation.finish()
                        isReceivingMessage = false
                    } catch {
                        Logger.service.error(error)
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
    }

    public func stopReceivingMessage() {
        cancelTask?()
        cancelTask = nil
        isReceivingMessage = false
    }

    public func restart() {
        history = []
    }

    public func mutateSystemPrompt(_ newPrompt: String) {
        systemPrompt = newPrompt
    }
}

extension ChatGPTService {
    func changeBuildCompletionStreamAPI(_ builder: @escaping CompletionStreamAPIBuilder) {
        buildCompletionStreamAPI = builder
    }

    func combineHistoryWithSystemPrompt() -> [CompletionRequestBody.Message] {
        if history.count > 4 {
            return [.init(role: .system, content: systemPrompt)] +
                history[history.endIndex - 4..<history.endIndex].map {
                    .init(role: $0.role, content: $0.content)
                }
        }
        return [.init(role: .system, content: systemPrompt)] + history.map {
            .init(role: $0.role, content: $0.content)
        }
    }
}
