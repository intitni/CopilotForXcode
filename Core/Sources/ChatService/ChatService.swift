import ChatContextCollector
import ChatPlugin
import Combine
import Foundation
import OpenAIService

let defaultSystemPrompt = """
You are an AI programming assistant.
Your reply should be concise, clear, informative and logical.
You MUST reply in the format of markdown.
You MUST embed every code you provide in a markdown code block.
You MUST add the programming language name at the start of the markdown code block.
If you are asked to help perform a task, you MUST think step-by-step, then describe each step concisely.
If you are asked to explain code, you MUST explain it step-by-step in a ordered list.
Make your answer short and structured.
"""

public final class ChatService: ObservableObject {
    public let chatGPTService: any ChatGPTServiceType
    let pluginController: ChatPluginController
    let contextController: DynamicContextController
    var cancellable = Set<AnyCancellable>()
    @Published public internal(set) var systemPrompt = defaultSystemPrompt
    @Published public internal(set) var extraSystemPrompt = ""

    public init<T: ChatGPTServiceType>(chatGPTService: T) {
        self.chatGPTService = chatGPTService
        pluginController = ChatPluginController(chatGPTService: chatGPTService, plugins: allPlugins)
        contextController = DynamicContextController(
            chatGPTService: chatGPTService,
            contextCollectors: ActiveDocumentChatContextCollector()
        )

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
        """, content: content)

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

    public func resetPrompt() async {
        systemPrompt = defaultSystemPrompt
        extraSystemPrompt = ""
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

    public func setMessageAsExtraPrompt(id: String) async {
        if let message = (await chatGPTService.history).first(where: { $0.id == id }) {
            mutateExtraSystemPrompt(message.content)
            await mutateHistory { history in
                history.append(.init(
                    role: .assistant,
                    content: "",
                    summary: "System prompt updated"
                ))
            }
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

