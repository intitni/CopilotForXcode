import Foundation
import OpenAIService

/// Quickly ask a question to ChatGPT.
func askChatGPT(systemPrompt: String, question: String) async throws -> String {
    let service = ChatGPTService(systemPrompt: systemPrompt)
    return try await service.sendAndWait(content: question)
}
