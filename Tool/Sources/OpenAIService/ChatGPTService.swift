import AsyncAlgorithms
import Dependencies
import Foundation
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

public class ChatGPTService: ChatGPTServiceType {
    public var memory: ChatGPTMemory
    public var configuration: ChatGPTConfiguration
    public var functionProvider: ChatGPTFunctionProvider

    var runningTask: Task<Void, Never>?
    var buildCompletionStreamAPI: CompletionStreamAPIBuilder = {
        apiKey, model, endpoint, requestBody, prompt in
        switch model.format {
        case .googleAI:
            return GoogleCompletionStreamAPI(
                apiKey: apiKey,
                model: model,
                requestBody: requestBody,
                prompt: prompt
            )
        case .openAI, .openAICompatible, .azureOpenAI:
            return OpenAICompletionStreamAPI(
                apiKey: apiKey,
                model: model,
                endpoint: endpoint,
                requestBody: requestBody
            )
        }
    }

    var buildCompletionAPI: CompletionAPIBuilder = {
        apiKey, model, endpoint, requestBody, prompt in
        switch model.format {
        case .googleAI:
            return GoogleCompletionAPI(
                apiKey: apiKey,
                model: model,
                requestBody: requestBody,
                prompt: prompt
            )
        case .openAI, .openAICompatible, .azureOpenAI:
            return OpenAICompletionAPI(
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
                functionCall: nil,
                summary: summary,
                references: []
            )
            await memory.appendMessage(newMessage)
        }

        return Debugger.$id.withValue(.init()) {
            AsyncThrowingStream<String, Error> { continuation in
                let task = Task(priority: .userInitiated) {
                    do {
                        var functionCall: ChatMessage.FunctionCall?
                        var functionCallMessageID = ""
                        var isInitialCall = true
                        loop: while functionCall != nil || isInitialCall {
                            try Task.checkCancellation()
                            isInitialCall = false
                            if let call = functionCall {
                                if !configuration.runFunctionsAutomatically {
                                    break loop
                                }
                                functionCall = nil
                                await runFunctionCall(call, messageId: functionCallMessageID)
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
                                case let .functionCall(call):
                                    if functionCall == nil {
                                        functionCallMessageID = uuid().uuidString
                                        functionCall = call
                                    } else {
                                        functionCall?.name.append(call.name)
                                        functionCall?.arguments.append(call.arguments)
                                    }
                                    await prepareFunctionCall(
                                        call,
                                        messageId: functionCallMessageID
                                    )
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
            var functionCall = message?.functionCall
            while let call = functionCall {
                try Task.checkCancellation()
                if !configuration.runFunctionsAutomatically {
                    break
                }
                functionCall = nil
                await runFunctionCall(call)
                guard let nextMessage = try await sendMemoryAndWait() else { break }
                finalResult = nextMessage.content
                functionCall = nextMessage.functionCall
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
        case functionCall(ChatMessage.FunctionCall)
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

        let messages = prompt.history.map {
            CompletionRequestBody.Message(
                role: $0.role,
                content: $0.content ?? "",
                name: $0.name,
                function_call: $0.functionCall.map {
                    .init(name: $0.name, arguments: $0.arguments)
                }
            )
        }
        let remainingTokens = prompt.remainingTokenCount

        let requestBody = CompletionRequestBody(
            model: model.info.modelName,
            messages: messages,
            temperature: configuration.temperature,
            stream: true,
            stop: configuration.stop.isEmpty ? nil : configuration.stop,
            max_tokens: maxTokenForReply(
                maxToken: model.info.maxTokens,
                remainingTokens: remainingTokens
            ),
            function_call: model.info.supportsFunctionCalling
                ? functionProvider.functionCallStrategy
                : nil,
            functions:
            model.info.supportsFunctionCalling
                ? functionProvider.functions.map {
                    ChatGPTFunctionSchema(
                        name: $0.name,
                        description: $0.description,
                        parameters: $0.argumentSchema
                    )
                }
                : []
        )

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
                        guard let delta = chunk.choices?.first?.delta else { continue }

                        // The api will always return a function call with JSON object.
                        // The first round will contain the function name and an empty argument.
                        // e.g. {"name":"weather","arguments":""}
                        // The other rounds will contain part of the arguments.
                        let functionCall = delta.function_call.map {
                            ChatMessage.FunctionCall(
                                name: $0.name ?? "",
                                arguments: $0.arguments ?? ""
                            )
                        }

                        await memory.streamMessage(
                            id: proposedId,
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

        let messages = prompt.history.map {
            CompletionRequestBody.Message(
                role: $0.role,
                content: $0.content ?? "",
                name: $0.name,
                function_call: $0.functionCall.map {
                    .init(name: $0.name, arguments: $0.arguments)
                }
            )
        }
        let remainingTokens = prompt.remainingTokenCount

        let requestBody = CompletionRequestBody(
            model: model.info.modelName,
            messages: messages,
            temperature: configuration.temperature,
            stream: true,
            stop: configuration.stop.isEmpty ? nil : configuration.stop,
            max_tokens: maxTokenForReply(
                maxToken: model.info.maxTokens,
                remainingTokens: remainingTokens
            ),
            function_call: model.info.supportsFunctionCalling
                ? functionProvider.functionCallStrategy
                : nil,
            functions:
            model.info.supportsFunctionCalling
                ? functionProvider.functions.map {
                    ChatGPTFunctionSchema(
                        name: $0.name,
                        description: $0.description,
                        parameters: $0.argumentSchema
                    )
                }
                : []
        )

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

        guard let choice = response.choices.first else { return nil }
        let message = ChatMessage(
            id: proposedId,
            role: choice.message.role,
            content: choice.message.content,
            name: choice.message.name,
            functionCall: choice.message.function_call.map {
                ChatMessage.FunctionCall(name: $0.name, arguments: $0.arguments ?? "")
            },
            references: prompt.references
        )
        await memory.appendMessage(message)
        return message
    }

    /// When a function call is detected, but arguments are not yet ready, we can call this
    /// to insert a message placeholder in memory.
    func prepareFunctionCall(_ call: ChatMessage.FunctionCall, messageId: String) async {
        guard let function = functionProvider.function(named: call.name) else { return }
        await memory.streamMessage(id: messageId, role: .function, name: call.name)
        await function.prepare { [weak self] summary in
            await self?.memory.updateMessage(id: messageId) { message in
                message.summary = summary
            }
        }
    }

    /// Run a function call from the bot, and insert the result in memory.
    @discardableResult
    func runFunctionCall(
        _ call: ChatMessage.FunctionCall,
        messageId: String? = nil
    ) async -> String {
        #if DEBUG
        Debugger.didReceiveFunction(name: call.name, arguments: call.arguments)
        #endif

        let messageId = messageId ?? uuid().uuidString

        guard let function = functionProvider.function(named: call.name) else {
            return await fallbackFunctionCall(call, messageId: messageId)
        }

        await memory.streamMessage(id: messageId, role: .function, name: call.name)

        do {
            // Run the function
            let result = try await function.call(argumentsJsonString: call.arguments) {
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
}

extension ChatGPTService {
    func changeBuildCompletionStreamAPI(_ builder: @escaping CompletionStreamAPIBuilder) {
        buildCompletionStreamAPI = builder
    }
}

func maxTokenForReply(maxToken: Int, remainingTokens: Int?) -> Int? {
    guard let remainingTokens else { return nil }
    return min(maxToken / 2, remainingTokens)
}

