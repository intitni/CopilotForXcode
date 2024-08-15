import AIModel
import AsyncAlgorithms
import ChatBasic
import Dependencies
import Foundation
import IdentifiedCollections
import Preferences

public enum ChatGPTResponse {
    case status(String)
    case partialText(String)
    case partialToolCall(ChatMessage.ToolCall)
}

public struct ChatGPTRequest {
    public var history: [ChatMessage]
    public var message: ChatMessage
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
}

public protocol ChatGPTServiceType {
    typealias Request = ChatGPTRequest
    typealias Response = ChatGPTResponse
    var configuration: ChatGPTConfiguration { get set }
    func send(_ request: Request) async -> ChatGPTResponseStream
}

public class ChatGPTService: ChatGPTServiceType {
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
        configuration: ChatGPTConfiguration = UserPreferenceChatGPTConfiguration(),
        functionProvider: ChatGPTFunctionProvider = NoChatGPTFunctionProvider()
    ) {
        self.configuration = configuration
        self.functionProvider = functionProvider
    }

    @Dependency(\.uuid) var uuid
    @Dependency(\.date) var date

    /// Send a message and stream the reply.
    public func send(_: Request) async -> ChatGPTResponseStream {
        return Debugger.$id.withValue(.init()) {
            AsyncThrowingStream<Response, Error> { continuation in
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
                                for await response in runFunctionCall(toolCall) {
                                    continuation.yield(.partialToolCall(response))
                                }
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
}

// - MARK: Internal

extension ChatGPTService {
    enum StreamContent {
        case text(String)
        case toolCall(ChatMessage.ToolCall)
    }

    enum FunctionCallResult {
        case status(String)
        case output(String)
    }

    /// Send the memory as prompt to ChatGPT, with stream enabled.
    func sendMemory(request: Request) async throws -> AsyncThrowingStream<StreamContent, Error> {
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

    /// When a function call is detected, but arguments are not yet ready, we can call this
    /// to report the status.
    func prepareFunctionCall(
        _ call: ChatMessage.ToolCall
    ) async -> AsyncStream<FunctionCallResult> {
        return .init { continuation in
            guard let function = functionProvider.function(named: call.function.name) else {
                continuation.finish()
            }
            let task = Task {
                await function.prepare { summary in
                    continuation.yield(.status(summary))
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
    func runFunctionCall(_ call: ChatMessage.ToolCall) async -> AsyncStream<FunctionCallResult> {
        #if DEBUG
        Debugger.didReceiveFunction(name: call.function.name, arguments: call.function.arguments)
        #endif

        return .init { continuation in

            let task = Task {
                guard let function = functionProvider.function(named: call.function.name) else {
                    let response = await fallbackFunctionCall(call)
                    continuation.yield(.output(response))
                    continuation.finish()
                    return
                }

                do {
                    // Run the function
                    let result = try await function
                        .call(argumentsJsonString: call.function.arguments) { summary in
                            continuation.yield(.status(summary))
                        }

                    #if DEBUG
                    Debugger.didReceiveFunctionResult(result: result.botReadableContent)
                    #endif

                    continuation.yield(.output(result.botReadableContent))
                    continuation.finish()
                } catch {
                    // For errors, use the error message as the result.
                    let content = "Error: \(error.localizedDescription)"

                    #if DEBUG
                    Debugger.didReceiveFunctionResult(result: content)
                    #endif

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
        _ call: ChatMessage.ToolCall
    ) async -> String {
        let service = ChatGPTService(
            configuration: OverridingChatGPTConfiguration(overriding: configuration, with: .init(
                temperature: 0
            )),
            functionProvider: NoChatGPTFunctionProvider()
        )

        let stream = await service.send(.init(
            history: [
                .init(role: .system, content: {
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
                }()),
            ],
            message: .init(role: .user, content: """
            \(call.function.arguments)
            """)
        ))

        do {
            return try await stream.asText()
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
}

extension ChatGPTService {
    func changeBuildCompletionStreamAPI(_ builder: @escaping ChatCompletionsStreamAPIBuilder) {
        buildCompletionStreamAPI = builder
    }
}

