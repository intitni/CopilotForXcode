import Foundation
import OpenAIService

/// Quickly ask a question to ChatGPT.
public func askChatGPT(
    systemPrompt: String,
    question: String,
    temperature: Double? = nil
) async throws -> String? {
    let configuration = UserPreferenceChatGPTConfiguration()
        .overriding(.init(temperature: temperature))
    let memory = AutoManagedChatGPTMemory(
        systemPrompt: systemPrompt,
        configuration: configuration,
        functionProvider: NoChatGPTFunctionProvider(), 
        maxNumberOfMessages: .max
    )
    let service = LegacyChatGPTService(
        memory: memory,
        configuration: configuration
    )
    return try await service.sendAndWait(content: question)
}

