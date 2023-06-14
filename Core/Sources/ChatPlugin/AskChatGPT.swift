import Foundation
import OpenAIService

/// Quickly ask a question to ChatGPT.
public func askChatGPT(
    systemPrompt: String,
    question: String,
    temperature: Double? = nil
) async throws -> String? {
    let service = ChatGPTService(
        systemPrompt: systemPrompt,
        configuration: OverridingUserPreferenceChatGPTConfiguration(
            overriding: .init(temperature: temperature)
        )
    )
    return try await service.sendAndWait(content: question)
}

