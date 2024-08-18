import AIModel
import AsyncAlgorithms
import ChatBasic
import Dependencies
import Foundation
import IdentifiedCollections
import Preferences

public enum ChatGPTServiceError: Error, LocalizedError {
    case chatModelNotAvailable
    case embeddingModelNotAvailable
    case endpointIncorrect
    case responseInvalid
    case unauthorized(String)
    case otherError(String)

    public var errorDescription: String? {
        switch self {
        case .chatModelNotAvailable:
            return "Chat model is not available, please add a model in the settings."
        case .embeddingModelNotAvailable:
            return "Embedding model is not available, please add a model in the settings."
        case .endpointIncorrect:
            return "ChatGPT endpoint is incorrect"
        case .responseInvalid:
            return "Response is invalid"
        case let .unauthorized(reason):
            return "Unauthorized: \(reason)"
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
        public var type: String?
        public var param: String?
        public var code: String?

        public init(
            message: String,
            type: String? = nil,
            param: String? = nil,
            code: String? = nil
        ) {
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

public enum ChatGPTResponse: Equatable {
    case status(String)
    case partialText(String)
    case toolCalls([ChatMessage.ToolCall])
}

public typealias ChatGPTResponseStream = AsyncThrowingStream<ChatGPTResponse, any Error>

public extension ChatGPTResponseStream {
    func asText() async throws -> String {
        var text = ""
        for try await case let .partialText(response) in self {
            text += response
        }
        return text
    }

    func asToolCalls() async throws -> [ChatMessage.ToolCall] {
        var toolCalls = [ChatMessage.ToolCall]()
        for try await case let .toolCalls(calls) in self {
            toolCalls.append(contentsOf: calls)
        }
        return toolCalls
    }

    func asArray() async throws -> [ChatGPTResponse] {
        var responses = [ChatGPTResponse]()
        for try await response in self {
            responses.append(response)
        }
        return responses
    }
}

public protocol ChatGPTServiceType {
    typealias Response = ChatGPTResponse
    var configuration: ChatGPTConfiguration { get set }
    func send(_ memory: ChatGPTMemory) -> ChatGPTResponseStream
}

public class ChatGPTService: ChatGPTServiceType {
    public var configuration: ChatGPTConfiguration
    public var functionProvider: ChatGPTFunctionProvider

    public init(
        configuration: ChatGPTConfiguration = UserPreferenceChatGPTConfiguration(),
        functionProvider: ChatGPTFunctionProvider = NoChatGPTFunctionProvider()
    ) {
        self.configuration = configuration
        self.functionProvider = functionProvider
    }

    @Dependency(\.uuid) var uuid
    @Dependency(\.date) var date
    @Dependency(\.chatCompletionsAPIBuilder) var chatCompletionsAPIBuilder

    /// Send the memory and stream the reply. While it's returning the results in a
    /// ``ChatGPTResponseStream``, it's also streaming the results to the memory.
    ///
    /// If ``ChatGPTConfiguration/runFunctionsAutomatically`` is enabled, the service will handle
    /// the tool calls inside the function. Otherwise, it will return the tool calls to the caller.
    public func send(_ memory: ChatGPTMemory) -> ChatGPTResponseStream {
        return Debugger.$id.withValue(.init()) {
            ChatGPTResponseStream { continuation in
                let task = Task(priority: .userInitiated) {
                    do {
                        var pendingToolCalls = [ChatMessage.ToolCall]()
                        var sourceMessageId = ""
                        var isInitialCall = true

                        loop: while !pendingToolCalls.isEmpty || isInitialCall {
                            try Task.checkCancellation()
                            isInitialCall = false

                            var functionCallResponses = [ChatCompletionsRequestBody.Message]()

                            if !pendingToolCalls.isEmpty {
                                if configuration.runFunctionsAutomatically {
                                    for toolCall in pendingToolCalls {
                                        for await response in await runFunctionCall(
                                            toolCall,
                                            memory: memory,
                                            sourceMessageId: sourceMessageId
                                        ) {
                                            switch response {
                                            case let .output(output):
                                                functionCallResponses.append(.init(
                                                    role: .tool,
                                                    content: output,
                                                    toolCallId: toolCall.id
                                                ))
                                            case let .status(status):
                                                continuation.yield(.status(status))
                                            }
                                        }
                                    }
                                } else {
                                    if !configuration.runFunctionsAutomatically {
                                        continuation.yield(.toolCalls(pendingToolCalls))
                                        continuation.finish()
                                        return
                                    }
                                }
                            }

                            sourceMessageId = uuid().uuidString
                            let stream = try await sendRequest(
                                memory: memory,
                                proposedMessageId: sourceMessageId
                            )

                            for try await content in stream {
                                try Task.checkCancellation()
                                switch content {
                                case let .partialText(text):
                                    continuation.yield(.partialText(text))

                                case let .partialToolCalls(toolCalls):
                                    guard configuration.runFunctionsAutomatically else { break }
                                    for toolCall in toolCalls.keys.sorted() {
                                        if let toolCallValue = toolCalls[toolCall] {
                                            for await status in await prepareFunctionCall(
                                                toolCallValue,
                                                memory: memory,
                                                sourceMessageId: sourceMessageId
                                            ) {
                                                continuation.yield(.status(status))
                                            }
                                        }
                                    }
                                }
                            }

                            let replyMessage = await memory.history
                                .last { $0.id == sourceMessageId }
                            pendingToolCalls = replyMessage?.toolCalls ?? []

                            #if DEBUG
                            Debugger.didReceiveResponse(content: replyMessage?.content ?? "")
                            #endif
                        }

                        #if DEBUG
                        Debugger.didFinish()
                        #endif
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
}

// - MARK: Internal

extension ChatGPTService {
    enum StreamContent {
        case partialText(String)
        case partialToolCalls([Int: ChatMessage.ToolCall])
    }

    enum FunctionCallResult {
        case status(String)
        case output(String)
    }

    /// Send the memory as prompt to ChatGPT, with stream enabled.
    func sendRequest(
        memory: ChatGPTMemory,
        proposedMessageId: String
    ) async throws -> AsyncThrowingStream<StreamContent, Error> {
        let prompt = await memory.generatePrompt()

        guard let model = configuration.model else {
            throw ChatGPTServiceError.chatModelNotAvailable
        }
        guard let url = URL(string: configuration.endpoint) else {
            throw ChatGPTServiceError.endpointIncorrect
        }

        let requestBody = createRequestBody(prompt: prompt, model: model, stream: true)

        let api = chatCompletionsAPIBuilder.buildStreamAPI(
            model: model,
            endpoint: url,
            apiKey: configuration.apiKey,
            requestBody: requestBody
        )

        #if DEBUG
        Debugger.didSendRequestBody(body: requestBody)
        #endif

        return AsyncThrowingStream<StreamContent, Error> { continuation in
            let task = Task {
                do {
                    await memory.streamMessage(
                        id: proposedMessageId,
                        role: .assistant,
                        references: prompt.references
                    )
                    let chunks = try await api()
                    for try await chunk in chunks {
                        try Task.checkCancellation()
                        guard let delta = chunk.message else { continue }

                        // The api will always return a function call with JSON object.
                        // The first round will contain the function name and an empty argument.
                        // e.g. {"name":"weather","arguments":""}
                        // The other rounds will contain part of the arguments.
                        let toolCalls = delta.toolCalls?
                            .reduce(into: [Int: ChatMessage.ToolCall]()) {
                                $0[$1.index ?? 0] = ChatMessage.ToolCall(
                                    id: $1.id ?? "",
                                    type: $1.type ?? "",
                                    function: .init(
                                        name: $1.function?.name ?? "",
                                        arguments: $1.function?.arguments ?? ""
                                    )
                                )
                            }

                        await memory.streamMessage(
                            id: proposedMessageId,
                            role: delta.role?.asChatMessageRole,
                            content: delta.content,
                            toolCalls: toolCalls
                        )

                        if let toolCalls {
                            continuation.yield(.partialToolCalls(toolCalls))
                        }

                        if let content = delta.content {
                            continuation.yield(.partialText(content))
                        }
                    }

                    continuation.finish()
                } catch let error as CancellationError {
                    continuation.finish(throwing: error)
                } catch let error as NSError where error.code == NSURLErrorCancelled {
                    continuation.finish(throwing: error)
                } catch {
                    await memory.appendMessage(.init(
                        id: uuid().uuidString,
                        role: .assistant,
                        content: error.localizedDescription
                    ))
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    /// When a function call is detected, but arguments are not yet ready, we can call this
    /// to report the status.
    func prepareFunctionCall(
        _ call: ChatMessage.ToolCall,
        memory: ChatGPTMemory,
        sourceMessageId: String
    ) async -> AsyncStream<String> {
        return .init { continuation in
            guard let function = functionProvider.function(named: call.function.name) else {
                continuation.finish()
                return
            }
            let task = Task {
                await memory.streamToolCallResponse(
                    id: sourceMessageId,
                    toolCallId: call.id
                )
                await function.prepare { summary in
                    continuation.yield(summary)
                    await memory.streamToolCallResponse(
                        id: sourceMessageId,
                        toolCallId: call.id,
                        summary: summary
                    )
                }
                continuation.finish()
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    /// Run a function call from the bot.
    @discardableResult
    func runFunctionCall(
        _ call: ChatMessage.ToolCall,
        memory: ChatGPTMemory,
        sourceMessageId: String
    ) async -> AsyncStream<FunctionCallResult> {
        #if DEBUG
        Debugger.didReceiveFunction(name: call.function.name, arguments: call.function.arguments)
        #endif

        return .init { continuation in
            let task = Task {
                guard let function = functionProvider.function(named: call.function.name) else {
                    let response = await fallbackFunctionCall(
                        call,
                        memory: memory,
                        sourceMessageId: sourceMessageId
                    )
                    continuation.yield(.output(response))
                    continuation.finish()
                    return
                }

                await memory.streamToolCallResponse(
                    id: sourceMessageId,
                    toolCallId: call.id
                )

                do {
                    // Run the function
                    let result = try await function
                        .call(argumentsJsonString: call.function.arguments) { summary in
                            continuation.yield(.status(summary))
                            await memory.streamToolCallResponse(
                                id: sourceMessageId,
                                toolCallId: call.id,
                                summary: summary
                            )
                        }

                    #if DEBUG
                    Debugger.didReceiveFunctionResult(result: result.botReadableContent)
                    #endif

                    await memory.streamToolCallResponse(
                        id: sourceMessageId,
                        toolCallId: call.id,
                        content: result.botReadableContent
                    )

                    continuation.yield(.output(result.botReadableContent))
                    continuation.finish()
                } catch {
                    // For errors, use the error message as the result.
                    let content = "Error: \(error.localizedDescription)"

                    #if DEBUG
                    Debugger.didReceiveFunctionResult(result: content)
                    #endif

                    await memory.streamToolCallResponse(
                        id: sourceMessageId,
                        toolCallId: call.id,
                        content: content,
                        summary: content
                    )

                    continuation.yield(.output(content))
                    continuation.finish()
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    /// Mock a function call result when the bot is calling a function that is not implemented.
    func fallbackFunctionCall(
        _ call: ChatMessage.ToolCall,
        memory: ChatGPTMemory,
        sourceMessageId: String
    ) async -> String {
        let temporaryMemory = ConversationChatGPTMemory(systemPrompt: {
            if call.function.name == "python" {
                return """
                Act like a Python interpreter.
                I will give you Python code and you will execute it.
                Reply with output of the code and tell me it's an answer generated by LLM.
                """
            } else {
                return """
                You are a function simulator. Your name is \(call.function.name).
                Act like a function.
                I will send you the arguments.
                Reply with output of the function and tell me it's an answer generated by LLM.
                """
            }
        }())

        let service = ChatGPTService(
            configuration: OverridingChatGPTConfiguration(
                overriding: UserPreferenceChatGPTConfiguration(
                    chatModelKey: \.preferredChatModelIdForUtilities
                ),
                with: .init(temperature: 0)
            ),
            functionProvider: NoChatGPTFunctionProvider()
        )

        let stream = service.send(temporaryMemory)

        do {
            let result = try await stream.asText()
            await memory.streamToolCallResponse(
                id: sourceMessageId,
                toolCallId: call.id,
                content: result,
                summary: "Finished running function."
            )
            return result
        } catch {
            return error.localizedDescription
        }
    }

    func createRequestBody(
        prompt: ChatGPTPrompt,
        model: ChatModel,
        stream: Bool
    ) -> ChatCompletionsRequestBody {
        let serviceSupportsFunctionCalling = switch model.format {
        case .openAI, .openAICompatible, .azureOpenAI:
            model.info.supportsFunctionCalling
        case .ollama, .googleAI, .claude:
            false
        }

        let messages = prompt.history.flatMap { chatMessage in
            var all = [ChatCompletionsRequestBody.Message]()
            all.append(ChatCompletionsRequestBody.Message(
                role: {
                    switch chatMessage.role {
                    case .system: .system
                    case .user: .user
                    case .assistant: .assistant
                    }
                }(),
                content: chatMessage.content ?? "",
                name: chatMessage.name,
                toolCalls: {
                    if serviceSupportsFunctionCalling {
                        chatMessage.toolCalls?.map {
                            .init(
                                id: $0.id,
                                type: $0.type,
                                function: .init(
                                    name: $0.function.name,
                                    arguments: $0.function.arguments
                                )
                            )
                        }
                    } else {
                        nil
                    }
                }()
            ))

            for call in chatMessage.toolCalls ?? [] {
                if serviceSupportsFunctionCalling {
                    all.append(ChatCompletionsRequestBody.Message(
                        role: .tool,
                        content: call.response.content,
                        toolCallId: call.id
                    ))
                } else {
                    all.append(ChatCompletionsRequestBody.Message(
                        role: .user,
                        content: call.response.content
                    ))
                }
            }

            return all
        }

        let remainingTokens = prompt.remainingTokenCount

        let requestBody = ChatCompletionsRequestBody(
            model: model.info.modelName,
            messages: messages,
            temperature: configuration.temperature,
            stream: stream,
            stop: configuration.stop.isEmpty ? nil : configuration.stop,
            maxTokens: maxTokenForReply(
                maxToken: model.info.maxTokens,
                remainingTokens: remainingTokens
            ),
            toolChoice: serviceSupportsFunctionCalling
                ? functionProvider.functionCallStrategy
                : nil,
            tools: serviceSupportsFunctionCalling
                ? functionProvider.functions.map {
                    .init(function: ChatGPTFunctionSchema(
                        name: $0.name,
                        description: $0.description,
                        parameters: $0.argumentSchema
                    ))
                }
                : []
        )

        return requestBody
    }
    
    
    func maxTokenForReply(maxToken: Int, remainingTokens: Int?) -> Int? {
        guard let remainingTokens else { return nil }
        return min(maxToken / 2, remainingTokens)
    }
}

