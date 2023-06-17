import AsyncAlgorithms
import Foundation
import GPTEncoder
import Preferences

public protocol ChatGPTServiceType {
    var memory: ChatGPTMemory { get set }
    var configuration: ChatGPTConfiguration { get set }
    func send(content: String, summary: String?) async throws -> AsyncThrowingStream<String, Error>
    func stopReceivingMessage() async
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

public class ChatGPTService: ChatGPTServiceType {
    public var memory: ChatGPTMemory
    public var configuration: ChatGPTConfiguration

    var uuidGenerator: () -> String = { UUID().uuidString }
    var cancelTask: Cancellable?
    var buildCompletionStreamAPI: CompletionStreamAPIBuilder = OpenAICompletionStreamAPI.init
    var buildCompletionAPI: CompletionAPIBuilder = OpenAICompletionAPI.init

    public init(
        memory: ChatGPTMemory = AutoManagedChatGPTMemory(
            systemPrompt: "",
            configuration: UserPreferenceChatGPTConfiguration()
        ),
        configuration: ChatGPTConfiguration = UserPreferenceChatGPTConfiguration()
    ) {
        self.memory = memory
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
                name: nil,
                functionCall: nil,
                summary: summary
            )
            await memory.appendMessage(newMessage)
        }

        let messages = await memory.messages.map {
            CompletionRequestBody.Message(role: $0.role, content: $0.content)
        }
        let remainingTokens = await memory.remainingTokens

        let requestBody = CompletionRequestBody(
            model: configuration.model,
            messages: messages,
            temperature: configuration.temperature,
            stream: true,
            stop: configuration.stop.isEmpty ? nil : configuration.stop,
            max_tokens: maxTokenForReply(
                model: configuration.model,
                remainingTokens: remainingTokens
            ),
            function_call: nil,
            functions: []
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
                    var id = ""
                    var functionCallRawString = ""
                    for try await trunk in trunks {
                        id = trunk.id

                        guard let delta = trunk.choices.first?.delta else { continue }

                        await memory.streamMessage(
                            id: trunk.id,
                            role: delta.role,
                            content: delta.content,
                            functionCall: nil
                        )

                        if let call = delta.function_call {
                            functionCallRawString.append(call)
                        }

                        if let content = delta.content {
                            continuation.yield(content)
                        }

                        try await Task.sleep(nanoseconds: 3_000_000)
                    }

                    if !functionCallRawString.isEmpty,
                       let data = functionCallRawString.data(using: .utf8)
                    {
                        let function = try JSONDecoder().decode(
                            ChatMessage.FunctionCall.self,
                            from: data
                        )
                        await memory.streamMessage(
                            id: id,
                            role: nil,
                            content: nil,
                            functionCall: function
                        )
                    }

                    continuation.finish()
                } catch let error as CancellationError {
                    continuation.finish(throwing: error)
                } catch let error as NSError where error.code == NSURLErrorCancelled {
                    continuation.finish(throwing: error)
                } catch {
                    await memory.appendMessage(.init(
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
        guard let url = URL(string: configuration.endpoint)
        else { throw ChatGPTServiceError.endpointIncorrect }

        if !content.isEmpty || summary != nil {
            let newMessage = ChatMessage(
                id: uuidGenerator(),
                role: .user,
                content: content,
                summary: summary
            )
            await memory.appendMessage(newMessage)
        }

        let messages = await memory.messages.map {
            CompletionRequestBody.Message(role: $0.role, content: $0.content)
        }
        let remainingTokens = await memory.remainingTokens

        let requestBody = CompletionRequestBody(
            model: configuration.model,
            messages: messages,
            temperature: configuration.temperature,
            stream: true,
            stop: configuration.stop.isEmpty ? nil : configuration.stop,
            max_tokens: maxTokenForReply(
                model: configuration.model,
                remainingTokens: remainingTokens
            ),
            function_call: nil,
            functions: []
        )

        let api = buildCompletionAPI(
            configuration.apiKey,
            configuration.featureProvider,
            url,
            requestBody
        )
        let response = try await api()

        if let choice = response.choices.first {
            await memory.appendMessage(.init(
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
}

extension ChatGPTService {
    func changeBuildCompletionStreamAPI(_ builder: @escaping CompletionStreamAPIBuilder) {
        buildCompletionStreamAPI = builder
    }

    func changeUUIDGenerator(_ generator: @escaping () -> String) {
        uuidGenerator = generator
    }
}

func maxTokenForReply(model: String, remainingTokens: Int?) -> Int? {
    guard let remainingTokens else { return nil }
    guard let model = ChatGPTModel(rawValue: model) else { return remainingTokens }
    return min(model.maxToken / 2, remainingTokens)
}

