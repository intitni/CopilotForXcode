import Foundation
import OpenAIService

public struct OpenAIChat: ChatModel {
    public var temperature: Double
    public var stream: Bool

    public init(
        temperature: Double = 0.7,
        stream: Bool = false
    ) {
        self.temperature = temperature
        self.stream = stream
    }

    public func generate(
        prompt: [ChatMessage],
        stops: [String],
        callbackManagers: [ChainCallbackManager]
    ) async throws -> String {
        let service = ChatGPTService(configuration: OverridingUserPreferenceChatGPTConfiguration(
            overriding: .init(
                temperature: temperature,
                stop: stops
            )
        ))
        await service.mutateHistory { history in
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
                history.append(.init(role: role, content: message.content))
            }
        }
        if stream {
            let stream = try await service.send(content: "")
            var message = ""
            for try await trunk in stream {
                message.append(trunk)
                callbackManagers.forEach { $0.onLLMNewToken(token: trunk) }
            }
            return message
        } else {
            return try await service.sendAndWait(content: "") ?? ""
        }
    }
}

