import ChatPlugins
import Combine
import Foundation
import OpenAIService

let defaultSystemPrompt = """
You are an AI programming assistant.
You reply should be concise, clear, informative and logical.
You MUST reply in the format of markdown.
You MUST embed every code you provide in a markdown code block.
You MUST add the programming language name at the start of the markdown code block.
If you are asked to help perform a task, think step-by-step.
"""

public final class ChatService: ObservableObject {
    public let chatGPTService: any ChatGPTServiceType
    let pluginController: ChatPluginController
    let contextController: DynamicContextController
    var cancellable = Set<AnyCancellable>()
    var systemPrompt = defaultSystemPrompt
    var extraSystemPrompt = ""

    public init<T: ChatGPTServiceType>(chatGPTService: T) {
        self.chatGPTService = chatGPTService
        pluginController = ChatPluginController(
            chatGPTService: chatGPTService,
            plugins:
            TerminalChatPlugin.self,
            AITerminalChatPlugin.self
        )
        contextController = DynamicContextController(chatGPTService: chatGPTService)

        chatGPTService.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }.store(in: &cancellable)
    }

    public func send(content: String) async throws {
        let handledInPlugin = try await pluginController.handleContent(content)
        if handledInPlugin { return }
        try await contextController.updatePromptToMatchContent(systemPrompt: """
        \(systemPrompt)
        \(extraSystemPrompt)
        """)

        _ = try await chatGPTService.send(content: content, summary: nil)
    }

    public func stopReceivingMessage() async {
        await pluginController.stopResponding()
        await chatGPTService.stopReceivingMessage()
    }

    public func clearHistory() async {
        await pluginController.cancel()
        await chatGPTService.clearHistory()
    }

    public func deleteMessage(id: String) async {
        await chatGPTService.mutateHistory { messages in
            messages.removeAll(where: { $0.id == id })
        }
    }

    public func resendMessage(id: String) async throws {
        if let message = (await chatGPTService.history).first(where: { $0.id == id }) {
            try await send(content: message.content)
        }
    }

    /// Setting it to `nil` to reset the system prompt
    public func mutateSystemPrompt(_ newPrompt: String?) {
        systemPrompt = newPrompt ?? defaultSystemPrompt
    }
    
    public func mutateExtraSystemPrompt(_ newPrompt: String) {
        extraSystemPrompt = newPrompt
    }

    public func mutateHistory(_ mutator: @escaping (inout [ChatMessage]) -> Void) async {
        await chatGPTService.mutateHistory(mutator)
    }
}

