import AIModel
import AsyncAlgorithms
import Dependencies
import Foundation
import IdentifiedCollections
import Preferences

public protocol ChatGPTServiceType {
    var memory: ChatGPTMemory { get set }
    var configuration: ChatGPTConfiguration { get set }
    func send(content: String, summary: String?) async throws -> AsyncThrowingStream<String, Error>
    func stopReceivingMessage() async
}

public enum ChatGPTServiceError: Error, LocalizedError {
    case chatModelNotAvailable
    case embeddingModelNotAvailable
    case endpointIncorrect
    case responseInvalid
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

typealias ChatCompletionsStreamAPIBuilder = (
    String,
    ChatModel,
    URL,
    ChatCompletionsRequestBody,
    ChatGPTPrompt
) -> any ChatCompletionsStreamAPI

typealias ChatCompletionsAPIBuilder = (
    String,
    ChatModel,
    URL,
    ChatCompletionsRequestBody,
    ChatGPTPrompt
) -> any ChatCompletionsAPI

public class ChatGPTService: ChatGPTServiceType {
    public var memory: ChatGPTMemory
    public var configuration: ChatGPTConfiguration
    public var functionProvider: ChatGPTFunctionProvider

    var runningTask: Task<Void, Never>?
    var buildCompletionStreamAPI: ChatCompletionsStreamAPIBuilder = {
        apiKey, model, endpoint, requestBody, prompt in
        switch model.format {
        case .googleAI:
            return GoogleAIChatCompletionsService(
                apiKey: apiKey,
                model: model,
                requestBody: requestBody,
                prompt: prompt
            )
        case .openAI, .openAICompatible, .azureOpenAI:
            return OpenAIChatCompletionsService(
                apiKey: apiKey,
                model: model,
                endpoint: endpoint,
                requestBody: requestBody
            )
        case .ollama:
            return OllamaChatCompletionsService(
                apiKey: apiKey,
                model: model,
                endpoint: endpoint,
                requestBody: requestBody
            )
        }
    }

    var buildCompletionAPI: ChatCompletionsAPIBuilder = {
        apiKey, model, endpoint, requestBody, prompt in
        switch model.format {
        case .googleAI:
            return GoogleAIChatCompletionsService(
                apiKey: apiKey,
                model: model,
                requestBody: requestBody,
                prompt: prompt
            )
        case .openAI, .openAICompatible, .azureOpenAI:
            return OpenAIChatCompletionsService(
                apiKey: apiKey,
                model: model,
                endpoint: endpoint,
                requestBody: requestBody
            )
        case .ollama:
            return OllamaChatCompletionsService(
                apiKey: apiKey,
                model: model,
                endpoint: endpoint,
                requestBody: requestBody
            )
        }
    }

    public init(
        memory: ChatGPTMemory = AutoManagedChatGPTMemory(
            systemPrompt: "",
            configuration: UserPreferenceChatGPTConfiguration(),
            functionProvider: NoChatGPTFunctionProvider()
        ),
        configuration: ChatGPTConfiguration = UserPreferenceChatGPTConfiguration(),
        functionProvider: ChatGPTFunctionProvider = NoChatGPTFunctionProvider()
    ) {
        self.memory = memory
        self.configuration = configuration
        self.functionProvider = functionProvider
    }

    @Dependency(\.uuid) var uuid
    @Dependency(\.date) var date

    /// Send a message and stream the reply.
    public func send(
        content: String,
        summary: String? = nil
    ) async throws -> AsyncThrowingStream<String, Error> {
        if !content.isEmpty || summary != nil {
            let newMessage = ChatMessage(
                id: uuid().uuidString,
                role: .user,
                content: content,
                name: nil,
                toolCalls: nil,
                summary: summary,
                references: []
            )
            await memory.appendMessage(newMessage)
        }

        return Debugger.$id.withValue(.init()) {
            AsyncThrowingStream<String, Error> { continuation in
                let task = Task(priority: .userInitiated) {
                    do {
                        var pendingToolCalls = IdentifiedArrayOf<ChatMessage.ToolCall>()
                        var functionCallMessageIDs = [String: String]()
                        var isInitialCall = true
                        loop: while !pendingToolCalls.isEmpty || isInitialCall {
                            try Task.checkCancellation()
                            isInitialCall = false
                            for toolCall in pendingToolCalls {
                                if !configuration.runFunctionsAutomatically {
                                    break loop
                                }
                                await runFunctionCall(
                                    toolCall,
                                    messageId: functionCallMessageIDs[toolCall.id]
                                )
                            }
                            let stream = try await sendMemory()

                            #if DEBUG
                            var reply = ""
                            #endif

                            for try await content in stream {
                                try Task.checkCancellation()
                                switch content {
                                case let .text(text):
                                    continuation.yield(text)
                                    #if DEBUG
                                    reply.append(text)
                                    #endif

                                case let .toolCall(toolCall):
                                    let id = storeToolCallsChunks(
                                        chunk: toolCall,
                                        into: &pendingToolCalls,
                                        messageIds: &functionCallMessageIDs
                                    )

                                    await prepareFunctionCall(toolCall, messageId: id)
                                }
                            }
                            #if DEBUG
                            Debugger.didReceiveResponse(content: reply)
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

    /// Send a message and get the reply in return.
    public func sendAndWait(
        content: String,
        summary: String? = nil
    ) async throws -> String? {
        if !content.isEmpty || summary != nil {
            let newMessage = ChatMessage(
                id: uuid().uuidString,
                role: .user,
                content: content,
                summary: summary
            )
            await memory.appendMessage(newMessage)
        }
        return try await Debugger.$id.withValue(.init()) {
            let message = try await sendMemoryAndWait()
            var finalResult = message?.content
            var toolCalls = message?.toolCalls
            while let calls = toolCalls, !calls.isEmpty {
                try Task.checkCancellation()
                if !configuration.runFunctionsAutomatically {
                    break
                }
                toolCalls = nil
                for call in calls {
                    await runFunctionCall(call)
                }
                guard let nextMessage = try await sendMemoryAndWait() else { break }
                finalResult = nextMessage.content
                toolCalls = nextMessage.toolCalls
            }

            #if DEBUG
            Debugger.didReceiveResponse(content: finalResult ?? "N/A")
            Debugger.didFinish()
            #endif

            return finalResult
        }
    }

    #warning("TODO: remove this and let the concurrency system handle it")
    public func stopReceivingMessage() {
        runningTask?.cancel()
        runningTask = nil
    }
}

// - MARK: Internal

extension ChatGPTService {
    enum StreamContent {
        case text(String)
        case toolCall(ChatMessage.ToolCall)
    }

    /// Send the memory as prompt to ChatGPT, with stream enabled.
    func sendMemory() async throws -> AsyncThrowingStream<StreamContent, Error> {
        let prompt = await memory.generatePrompt()

        guard let model = configuration.model else {
            throw ChatGPTServiceError.chatModelNotAvailable
        }
        guard let url = URL(string: configuration.endpoint) else {
            throw ChatGPTServiceError.endpointIncorrect
        }

        let requestBody = createRequestBody(prompt: prompt, model: model, stream: true)

        let api = buildCompletionStreamAPI(
            configuration.apiKey,
            model,
            url,
            requestBody,
            prompt
        )

        #if DEBUG
        Debugger.didSendRequestBody(body: requestBody)
        #endif

        let proposedId = uuid().uuidString + String(date().timeIntervalSince1970)

        return AsyncThrowingStream<StreamContent, Error> { continuation in
            let task = Task {
                do {
                    await memory.streamMessage(
                        id: proposedId,
                        references: prompt.references
                    )
                    let chunks = try await api()
                    for try await chunk in chunks {
                        if Task.isCancelled {
                            throw CancellationError()
                        }
                        guard let delta = chunk.message else { continue }

                        // The api will always return a function call with JSON object.
                        // The first round will contain the function name and an empty argument.
                        // e.g. {"name":"weather","arguments":""}
                        // The other rounds will contain part of the arguments.
                        let toolCalls = delta.toolCalls?.map {
                            ChatMessage.ToolCall(
                                id: $0.id ?? "",
                                type: $0.type ?? "",
                                function: .init(
                                    name: $0.function?.name ?? "",
                                    arguments: $0.function?.arguments ?? ""
                                )
                            )
                        }

                        await memory.streamMessage(
                            id: proposedId,
                            role: delta.role,
                            content: delta.content,
                            toolCalls: toolCalls
                        )

                        if let toolCalls {
                            for toolCall in toolCalls {
                                continuation.yield(.toolCall(toolCall))
                            }
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

            runningTask = task

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    /// Send the memory as prompt to ChatGPT, with stream disabled.
    func sendMemoryAndWait() async throws -> ChatMessage? {
        let proposedId = uuid().uuidString + String(date().timeIntervalSince1970)
        let prompt = await memory.generatePrompt()

        guard let model = configuration.model else {
            throw ChatGPTServiceError.chatModelNotAvailable
        }
        guard let url = URL(string: configuration.endpoint) else {
            throw ChatGPTServiceError.endpointIncorrect
        }

        let requestBody = createRequestBody(prompt: prompt, model: model, stream: false)

        let api = buildCompletionAPI(
            configuration.apiKey,
            model,
            url,
            requestBody,
            prompt
        )

        #if DEBUG
        Debugger.didSendRequestBody(body: requestBody)
        #endif

        let response = try await api()

        let choice = response.message
        let message = ChatMessage(
            id: proposedId,
            role: choice.role,
            content: choice.content,
            name: choice.name,
            toolCalls: choice.toolCalls?.map {
                ChatMessage.ToolCall(id: $0.id, type: $0.type, function: .init(
                    name: $0.function.name,
                    arguments: $0.function.arguments ?? ""
                ))
            },
            references: prompt.references
        )
        await memory.appendMessage(message)
        return message
    }

    func storeToolCallsChunks(
        chunk toolCall: ChatMessage.ToolCall,
        into toolCalls: inout IdentifiedArrayOf<ChatMessage.ToolCall>,
        messageIds: inout [String: String]
    ) -> String {
        if let index = toolCalls.firstIndex(where: { $0.id == toolCall.id }) {
            if !toolCall.id.isEmpty {
                toolCalls[index].id = toolCall.id
            }
            if !toolCall.type.isEmpty {
                toolCalls[index].type = toolCall.type
            }
            toolCalls[index].function.name.append(toolCall.function.name)
            toolCalls[index].function.arguments.append(toolCall.function.arguments)

        } else {
            toolCalls.append(toolCall)
        }

        let id = messageIds[toolCall.id] ?? UUID().uuidString
        messageIds[toolCall.id] = id
        return id
    }

    /// When a function call is detected, but arguments are not yet ready, we can call this
    /// to insert a message placeholder in memory.
    func prepareFunctionCall(_ call: ChatMessage.ToolCall, messageId: String) async {
        guard let function = functionProvider.function(named: call.function.name) else { return }
        await memory.streamMessage(
            id: messageId,
            role: .tool,
            name: call.function.name,
            toolCallId: call.id
        )
        await function.prepare { [weak self] summary in
            await self?.memory.updateMessage(id: messageId) { message in
                message.summary = summary
            }
        }
    }

    /// Run a function call from the bot, and insert the result in memory.
    @discardableResult
    func runFunctionCall(
        _ call: ChatMessage.ToolCall,
        messageId: String? = nil
    ) async -> String {
        #if DEBUG
        Debugger.didReceiveFunction(name: call.function.name, arguments: call.function.arguments)
        #endif

        let messageId = messageId ?? uuid().uuidString

        guard let function = functionProvider.function(named: call.function.name) else {
            return await fallbackFunctionCall(call.function, messageId: messageId)
        }

        await memory.streamMessage(
            id: messageId,
            role: .function,
            name: call.function.name,
            toolCallId: call.id
        )

        do {
            // Run the function
            let result = try await function.call(argumentsJsonString: call.function.arguments) {
                [weak self] summary in
                await self?.memory.updateMessage(id: messageId) { message in
                    message.summary = summary
                }
            }

            #if DEBUG
            Debugger.didReceiveFunctionResult(result: result.botReadableContent)
            #endif

            await memory.updateMessage(id: messageId) { message in
                message.content = result.botReadableContent
            }

            return result.botReadableContent
        } catch {
            // For errors, use the error message as the result.
            let content = "Error: \(error.localizedDescription)"

            #if DEBUG
            Debugger.didReceiveFunctionResult(result: content)
            #endif

            await memory.updateMessage(id: messageId) { message in
                message.content = content
            }
            return content
        }
    }

    /// Mock a function call result when the bot is calling a function that is not implemented.
    func fallbackFunctionCall(
        _ call: ChatMessage.FunctionCall,
        messageId: String
    ) async -> String {
        let memory = ConversationChatGPTMemory(systemPrompt: {
            if call.name == "python" {
                return """
                Act like a Python interpreter.
                I will give you Python code and you will execute it.
                Reply with output of the code and tell me it's an answer generated by LLM.
                """
            } else {
                return """
                You are a function simulator. Your name is \(call.name).
                Act like a function.
                I will send you the arguments.
                Reply with output of the function and tell me it's an answer generated by LLM.
                """
            }
        }())

        let service = ChatGPTService(
            memory: memory,
            configuration: OverridingChatGPTConfiguration(overriding: configuration, with: .init(
                temperature: 0
            )),
            functionProvider: NoChatGPTFunctionProvider()
        )

        let content: String = await {
            do {
                return try await service.sendAndWait(content: """
                \(call.arguments)
                """) ?? "No result."
            } catch {
                return "No result."
            }
        }()
        await memory.streamMessage(
            id: messageId,
            role: .function,
            content: content,
            name: call.name,
            summary: "Finished running function."
        )
        return content
    }

    func createRequestBody(
        prompt: ChatGPTPrompt,
        model: ChatModel,
        stream: Bool
    ) -> ChatCompletionsRequestBody {
        let messages = prompt.history.map {
            ChatCompletionsRequestBody.Message(
                role: $0.role,
                content: $0.content ?? "",
                name: $0.name,
                toolCalls: $0.toolCalls?.map {
                    .init(
                        id: $0.id,
                        type: $0.type,
                        function: .init(
                            name: $0.function.name,
                            arguments: $0.function.arguments
                        )
                    )
                }
            )
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
            toolChoice: model.info.supportsFunctionCalling
                ? functionProvider.functionCallStrategy
                : nil,
            tools: model.info.supportsFunctionCalling
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
}

extension ChatGPTService {
    func changeBuildCompletionStreamAPI(_ builder: @escaping ChatCompletionsStreamAPIBuilder) {
        buildCompletionStreamAPI = builder
    }
}

func maxTokenForReply(maxToken: Int, remainingTokens: Int?) -> Int? {
    guard let remainingTokens else { return nil }
    return min(maxToken / 2, remainingTokens)
}

