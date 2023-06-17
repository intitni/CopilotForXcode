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
    public var functionProvider: ChatGPTFunctionProvider

    var uuidGenerator: () -> String = { UUID().uuidString }
    var cancelTask: Cancellable?
    var buildCompletionStreamAPI: CompletionStreamAPIBuilder = OpenAICompletionStreamAPI.init
    var buildCompletionAPI: CompletionAPIBuilder = OpenAICompletionAPI.init

    public init(
        memory: ChatGPTMemory = AutoManagedChatGPTMemory(
            systemPrompt: "",
            configuration: UserPreferenceChatGPTConfiguration()
        ),
        configuration: ChatGPTConfiguration = UserPreferenceChatGPTConfiguration(),
        functionProvider: ChatGPTFunctionProvider = NoChatGPTFunctionProvider()
    ) {
        self.memory = memory
        self.configuration = configuration
        self.functionProvider = functionProvider
    }

    /// Send a message and stream the reply.
    public func send(
        content: String,
        summary: String? = nil
    ) async throws -> AsyncThrowingStream<String, Error> {
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

        return AsyncThrowingStream<String, Error> { continuation in
            Task(priority: .userInitiated) {
                do {
                    let stream = try await sendMemory()
                    var functionCall: ChatMessage.FunctionCall?
                    var functionCallMessageID = uuidGenerator()
                    for try await content in stream {
                        switch content {
                        case let .text(text):
                            continuation.yield(text)
                        case let .functionCall(call):
                            functionCall = call
                            await prepareFunctionCall(call, messageId: functionCallMessageID)
                        }
                    }

                    while let call = functionCall {
                        functionCall = nil
                        await runFunctionCall(call)
                        functionCallMessageID = uuidGenerator()
                        let nextStream = try await sendMemory()
                        for try await content in nextStream {
                            switch content {
                            case let .text(text):
                                continuation.yield(text)
                            case let .functionCall(call):
                                functionCall = call
                                await prepareFunctionCall(call, messageId: functionCallMessageID)
                            }
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    /// Send a message and get the reply in return.
    public func sendAndWait(
        content: String,
        summary: String? = nil
    ) async throws -> String? {
        if !content.isEmpty || summary != nil {
            let newMessage = ChatMessage(
                id: uuidGenerator(),
                role: .user,
                content: content,
                summary: summary
            )
            await memory.appendMessage(newMessage)
        }

        let message = try await sendMemoryAndWait()
        var finalResult = message?.content
        var functionCall = message?.functionCall
        while let call = functionCall {
            functionCall = nil
            await runFunctionCall(call)
            guard let nextMessage = try await sendMemoryAndWait() else { break }
            finalResult = nextMessage.content
            functionCall = nextMessage.functionCall
        }

        return finalResult
    }

    public func stopReceivingMessage() {
        cancelTask?()
        cancelTask = nil
    }
}

// - MARK: Internal

extension ChatGPTService {
    enum StreamContent {
        case text(String)
        case functionCall(ChatMessage.FunctionCall)
    }

    /// Send the memory as prompt to ChatGPT, with stream enabled.
    func sendMemory() async throws -> AsyncThrowingStream<StreamContent, Error> {
        guard let url = URL(string: configuration.endpoint)
        else { throw ChatGPTServiceError.endpointIncorrect }

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
            functions: functionProvider.functionSchemas
        )

        let api = buildCompletionStreamAPI(
            configuration.apiKey,
            configuration.featureProvider,
            url,
            requestBody
        )

        return AsyncThrowingStream<StreamContent, Error> { continuation in
            Task {
                do {
                    let (trunks, cancel) = try await api()
                    cancelTask = cancel
                    for try await trunk in trunks {
                        guard let delta = trunk.choices.first?.delta else { continue }

                        // The api will always return a function call with correct JSON format.
                        // The first round will contain the function name and an empty argument.
                        // e.g. {"name":"weather","arguments":""}
                        let functionCall: ChatMessage.FunctionCall? = delta.function_call.flatMap {
                            guard let data = $0.data(using: .utf8) else { return nil }
                            return try? JSONDecoder()
                                .decode(ChatMessage.FunctionCall.self, from: data)
                        }

                        await memory.streamMessage(
                            id: trunk.id,
                            role: delta.role,
                            content: delta.content,
                            functionCall: functionCall
                        )

                        if let functionCall {
                            continuation.yield(.functionCall(functionCall))
                        }

                        if let content = delta.content {
                            continuation.yield(.text(content))
                        }

                        try await Task.sleep(nanoseconds: 3_000_000)
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

    /// Send the memory as prompt to ChatGPT, with stream disabled.
    func sendMemoryAndWait() async throws -> ChatMessage? {
        guard let url = URL(string: configuration.endpoint)
        else { throw ChatGPTServiceError.endpointIncorrect }

        let messages = await memory.messages.map {
            CompletionRequestBody.Message(
                role: $0.role,
                content: $0.content,
                name: $0.name,
                function_call: $0.functionCall.map {
                    CompletionRequestBody
                        .MessageFunctionCall(name: $0.name, arguments: $0.arguments)
                }
            )
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
            functions: functionProvider.functionSchemas
        )

        let api = buildCompletionAPI(
            configuration.apiKey,
            configuration.featureProvider,
            url,
            requestBody
        )
        let response = try await api()

        guard let choice = response.choices.first else { return nil }
        let message = ChatMessage(
            id: response.id,
            role: choice.message.role,
            content: choice.message.content,
            name: choice.message.name,
            functionCall: choice.message.function_call.map {
                ChatMessage.FunctionCall(name: $0.name, arguments: $0.arguments)
            }
        )
        await memory.appendMessage(message)
        return message
    }
    
    /// When a function call is detected, but arguments are not yet ready, we can call this
    /// to insert a message placeholder in memory.
    func prepareFunctionCall(_ call: ChatMessage.FunctionCall, messageId: String) async {
        guard let function = functionProvider.function(named: call.name) else { return }
        let responseMessage = ChatMessage(
            id: messageId,
            role: .function,
            content: nil,
            summary: function.message(at: .detected)
        )
        await memory.appendMessage(responseMessage)
    }

    /// Run a function call from the bot, and insert the result in memory.
    @discardableResult
    func runFunctionCall(
        _ call: ChatMessage.FunctionCall,
        messageId: String? = nil
    ) async -> String {
        let messageId = messageId ?? uuidGenerator()

        guard let function = functionProvider.function(named: call.name) else {
            let content = "Error: function not found"
            let responseMessage = ChatMessage(
                id: messageId,
                role: .function,
                content: content,
                summary: "Function `\(call.name)` not found."
            )
            await memory.appendMessage(responseMessage)
            return content
        }

        // Insert the chat message into memory to indicate the start of the function.
        let responseMessage = ChatMessage(
            id: messageId,
            role: .function,
            content: nil,
            summary: function
                .message(at: .processing(argumentsJsonString: call.arguments ?? ""))
        )
        await memory.appendMessage(responseMessage)

        do {
            // Run the function
            let response = try await function
                .call(argumentsJsonString: call.arguments ?? "")

            // Update the message to display the finish state of the function.
            await memory.updateMessage(id: messageId) { message in
                message.content = response
                message.summary = function.message(at: .ended(
                    argumentsJsonString: call.arguments ?? "",
                    result: response
                ))
            }
            return response
        } catch {
            // For errors, use the error message as the result.
            let content = "Error: \(error.localizedDescription)"
            await memory.updateMessage(id: messageId) { message in
                message.content = content
                message.summary = function.message(at: .error(
                    argumentsJsonString: call.arguments ?? "",
                    result: error
                ))
            }
            return content
        }
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

