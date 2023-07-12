import Foundation
import OpenAIService

public struct OpenAIChat: ChatModel {
    public var configuration: ChatGPTConfiguration
    public var memory: ChatGPTMemory
    public var functionProvider: ChatGPTFunctionProvider
    public var stream: Bool

    public init(
        configuration: ChatGPTConfiguration = UserPreferenceChatGPTConfiguration(),
        memory: ChatGPTMemory = ConversationChatGPTMemory(systemPrompt: ""),
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
    ) async throws -> String {
        let service = ChatGPTService(
            memory: memory,
            configuration: configuration,
            functionProvider: functionProvider
        )
        for message in prompt {
            let role: OpenAIService.ChatMessage.Role = {
                switch message.role {
                case .system:
                    return .system
                case .user:
                    return .user
                case .assistant:
                    return .assistant
                }
            }()
            await memory.appendMessage(.init(role: role, content: message.content))
        }

        if stream {
            let stream = try await service.send(content: "")
            var message = ""
            for try await trunk in stream {
                message.append(trunk)
                callbackManagers
                    .forEach { $0.send(CallbackEvents.LLMDidProduceNewToken(info: trunk)) }
            }
            return message
        } else {
            return try await service.sendAndWait(content: "") ?? ""
        }
    }
}

