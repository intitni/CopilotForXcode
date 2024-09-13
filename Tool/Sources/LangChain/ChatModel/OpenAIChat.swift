import Foundation
import OpenAIService

public struct OpenAIChat: ChatModel {
    public var configuration: ChatGPTConfiguration
    public var memory: ChatGPTMemory?
    public var functionProvider: ChatGPTFunctionProvider
    public var stream: Bool

    public init(
        configuration: ChatGPTConfiguration = UserPreferenceChatGPTConfiguration(),
        memory: ChatGPTMemory? = ConversationChatGPTMemory(systemPrompt: ""),
        functionProvider: ChatGPTFunctionProvider = NoChatGPTFunctionProvider(),
        stream: Bool
    ) {
        self.configuration = configuration
        self.memory = memory
        self.functionProvider = functionProvider
        self.stream = stream
    }

    public func generate(
        prompt: [ChatMessage],
        stops: [String],
        callbackManagers: [CallbackManager]
    ) async throws -> ChatMessage {
        let memory = memory ?? EmptyChatGPTMemory()
        
        let service = LegacyChatGPTService(
            memory: memory,
            configuration: configuration,
            functionProvider: functionProvider
        )
        for message in prompt {
            await memory.appendMessage(message)
        }

        if stream {
            let stream = try await service.send(content: "")
            var message = ""
            for try await chunk in stream {
                message.append(chunk)
                callbackManagers.send(CallbackEvents.LLMDidProduceNewToken(info: chunk))
            }
            return await memory.history.last ?? .init(role: .assistant, content: "")
        } else {
            let _ = try await service.sendAndWait(content: "")
            return await memory.history.last ?? .init(role: .assistant, content: "")
        }
    }
}

