import Foundation
import OpenAIService

public protocol ChatContextCollector {
    func generateSystemPrompt(history: [ChatMessage], content: String) -> String
}

