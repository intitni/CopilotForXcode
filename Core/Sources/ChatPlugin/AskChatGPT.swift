import Foundation
import OpenAIService

/// Quickly ask a question to ChatGPT.
public func askChatGPT(
    systemPrompt: String,
    question: String,
    temperature: Double? = nil
) async throws -> String? {
    let configuration = OverridingUserPreferenceChatGPTConfiguration(
        overriding: .init(temperature: temperature)
    )
    let memory = AutoManagedChatGPTMemory(systemPrompt: systemPrompt, configuration: configuration)
    let service = ChatGPTService(
        memory: memory,
        configuration: OverridingUserPreferenceChatGPTConfiguration(
            overriding: .init(temperature: temperature)
        )
    )
    return try await service.sendAndWait(content: question)
}

