import Foundation
import OpenAIService

public protocol ChatModel {
    func generate(
        prompt: [ChatMessage],
        stops: [String],
        callbackManagers: [CallbackManager]
    ) async throws -> ChatMessage
}

public typealias ChatMessage = OpenAIService.ChatMessage
    
public extension CallbackEvents {
    struct LLMDidProduceNewToken: CallbackEvent {
        public let info: String
    }
    
    var llmDidProduceNewToken: LLMDidProduceNewToken.Type {
        LLMDidProduceNewToken.self
    }
}
