import ChatContextCollector
import Foundation
import OpenAIService
import Preferences
import XcodeInspector

final class DynamicContextController {
    let chatGPTService: any ChatGPTServiceType
    let contextCollectors: [ChatContextCollector]

    init(chatGPTService: any ChatGPTServiceType, contextCollectors: ChatContextCollector...) {
        self.chatGPTService = chatGPTService
        self.contextCollectors = contextCollectors
    }

    func updatePromptToMatchContent(systemPrompt: String) async throws {
        let language = UserDefaults.shared.value(for: \.chatGPTLanguage)
        let oldMessages = (await chatGPTService.history).map(\.content)
        let contextualSystemPrompt = """
        \(language.isEmpty ? "" : "You must always reply in \(language)")
        \(systemPrompt)

        \(
            contextCollectors
                .map { $0.generateSystemPrompt(oldMessages: oldMessages) }
                .joined(separator: "\n")
        )
        """
        await chatGPTService.mutateSystemPrompt(contextualSystemPrompt)
    }
}

