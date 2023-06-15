import ChatContextCollector
import Foundation
import OpenAIService
import Preferences
import XcodeInspector

final class DynamicContextController {
    let contextCollectors: [ChatContextCollector]
    let memory: AutoManagedChatGPTMemory

    init(memory: AutoManagedChatGPTMemory, contextCollectors: ChatContextCollector...) {
        self.memory = memory
        self.contextCollectors = contextCollectors
    }

    func updatePromptToMatchContent(systemPrompt: String, content: String) async throws {
        let language = UserDefaults.shared.value(for: \.chatGPTLanguage)
        let oldMessages = (await memory.history).map(\.content)
        let contextualSystemPrompt = """
        \(language.isEmpty ? "" : "You must always reply in \(language)")
        \(systemPrompt)

        \(
            contextCollectors
                .map { $0.generateSystemPrompt(history: oldMessages, content: content) }
                .joined(separator: "\n")
        )
        """
        await memory.mutateSystemPrompt(contextualSystemPrompt)
    }
}

