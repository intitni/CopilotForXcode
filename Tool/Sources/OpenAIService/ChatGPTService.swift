import AIModel
import AsyncAlgorithms
import ChatBasic
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

        if model.id == "com.github.copilot" {
            return BuiltinExtensionChatCompletionsService(
                extensionIdentifier: model.id,
                requestBody: requestBody
            )
        }

        switch model.format {
        case .googleAI:
            return GoogleAIChatCompletionsService(
                apiKey: apiKey,
                model: model,
                requestBody: requestBody,
                prompt: prompt,
                baseURL: endpoint.absoluteString
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
        case .claude:
            return ClaudeChatCompletionsService(
                apiKey: apiKey,
                model: model,
                endpoint: endpoint,
                requestBody: requestBody
            )
        }
    }

    var buildCompletionAPI: ChatCompletionsAPIBuilder = {
        apiKey, model, endpoint, requestBody, prompt in

        if model.id == "com.github.copilot" {
            return BuiltinExtensionChatCompletionsService(
                extensionIdentifier: model.id,
                requestBody: requestBody
            )
        }

        switch model.format {
        case .googleAI:
            return GoogleAIChatCompletionsService(
                apiKey: apiKey,
                model: model,
                requestBody: requestBody,
                prompt: prompt,
                baseURL: endpoint.absoluteString
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
        case .claude:
            return ClaudeChatCompletionsService(
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
                        var pendingToolCalls = [ChatMessage.ToolCall]()
                        var sourceMessageId = ""
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
                                    sourceMessageId: sourceMessageId
                                )
                            }
                            sourceMessageId = uuid()
                                .uuidString + String(date().timeIntervalSince1970)
                            let stream = try await sendMemory(proposedId: sourceMessageId)

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
                                    await prepareFunctionCall(
                                        toolCall,
                                        sourceMessageId: sourceMessageId
                                    )
                                }
                            }

                            pendingToolCalls = await memory.history
                                .last { $0.id == sourceMessageId }?
                                .toolCalls ?? []

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
            while let sourceMessageId = message?.id, let calls = toolCalls, !calls.isEmpty {
                try Task.checkCancellation()
                if !configuration.runFunctionsAutomatically {
                    break
                }
                toolCalls = nil
                for call in calls {
                    await runFunctionCall(call, sourceMessageId: sourceMessageId)
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

    #warning("TODO: Move the cancellation up to the caller.")
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
    func sendMemory(proposedId: String) async throws -> AsyncThrowingStream<StreamContent, Error> {
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

        return AsyncThrowingStream<StreamContent, Error> { continuation in
            let task = Task {
                do {
                    await memory.streamMessage(
                        id: proposedId,
                        role: .assistant,
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
                            id: proposedId,
                            role: delta.role?.asChatMessageRole,
                            content: delta.content,
                            toolCalls: toolCalls
                        )

                        if let toolCalls {
                            for toolCall in toolCalls.values {
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
            role: {
                switch choice.role {
                case .system: .system
                case .user: .user
                case .assistant: .assistant
                case .tool: .user
                }
            }(),
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

    /// When a function call is detected, but arguments are not yet ready, we can call this
    /// to insert a message placeholder in memory.
    func prepareFunctionCall(_ call: ChatMessage.ToolCall, sourceMessageId: String) async {
        guard let function = functionProvider.function(named: call.function.name) else { return }
        await memory.streamToolCallResponse(id: sourceMessageId, toolCallId: call.id)
        await function.prepare { [weak self] summary in
            await self?.memory.streamToolCallResponse(
                id: sourceMessageId,
                toolCallId: call.id,
                summary: summary
            )
        }
    }

    /// Run a function call from the bot, and insert the result in memory.
    @discardableResult
    func runFunctionCall(
        _ call: ChatMessage.ToolCall,
        sourceMessageId: String
    ) async -> String {
        #if DEBUG
        Debugger.didReceiveFunction(name: call.function.name, arguments: call.function.arguments)
        #endif

        guard let function = functionProvider.function(named: call.function.name) else {
            return await fallbackFunctionCall(call, sourceMessageId: sourceMessageId)
        }

        await memory.streamToolCallResponse(
            id: sourceMessageId,
            toolCallId: call.id
        )

        do {
            // Run the function
            let result = try await function.call(argumentsJsonString: call.function.arguments) {
                [weak self] summary in
                await self?.memory.streamToolCallResponse(
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

            return result.botReadableContent
        } catch {
            // For errors, use the error message as the result.
            let content = "Error: \(error.localizedDescription)"

            #if DEBUG
            Debugger.didReceiveFunctionResult(result: content)
            #endif

            await memory.streamToolCallResponse(
                id: sourceMessageId,
                toolCallId: call.id,
                content: content
            )
            return content
        }
    }

    /// Mock a function call result when the bot is calling a function that is not implemented.
    func fallbackFunctionCall(
        _ call: ChatMessage.ToolCall,
        sourceMessageId: String
    ) async -> String {
        let memory = ConversationChatGPTMemory(systemPrompt: {
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
            memory: memory,
            configuration: OverridingChatGPTConfiguration(overriding: configuration, with: .init(
                temperature: 0
            )),
            functionProvider: NoChatGPTFunctionProvider()
        )

        let content: String = await {
            do {
                return try await service.sendAndWait(content: """
                \(call.function.arguments)
                """) ?? "No result."
            } catch {
                return "No result."
            }
        }()
        await memory.streamToolCallResponse(
            id: sourceMessageId,
            toolCallId: call.id,
            content: content,
            summary: "Finished running function."
        )
        return content
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

