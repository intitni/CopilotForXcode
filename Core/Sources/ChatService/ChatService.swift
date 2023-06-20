import ChatContextCollector
import ChatPlugin
import Combine
import Foundation
import OpenAIService

public final class ChatService: ObservableObject {
    public let chatGPTService: any ChatGPTServiceType
    public var allPluginCommands: [String] { allPlugins.map { $0.command } }
    let pluginController: ChatPluginController
    let contextController: DynamicContextController
    var cancellable = Set<AnyCancellable>()
    @Published public internal(set) var isReceivingMessage = false
    @Published public internal(set) var systemPrompt = UserDefaults.shared
        .value(for: \.defaultChatSystemPrompt)
    @Published public internal(set) var extraSystemPrompt = ""

    public init<T: ChatGPTServiceType>(chatGPTService: T) {
        self.chatGPTService = chatGPTService
        pluginController = ChatPluginController(chatGPTService: chatGPTService, plugins: allPlugins)
        contextController = DynamicContextController(
            chatGPTService: chatGPTService,
            contextCollectors: ActiveDocumentChatContextCollector()
        )

        pluginController.chatService = self
        chatGPTService.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }.store(in: &cancellable)
    }

    public func send(content: String) async throws {
        guard !isReceivingMessage else { throw CancellationError() }
        let handledInPlugin = try await pluginController.handleContent(content)
        if handledInPlugin { return }
        try await contextController.updatePromptToMatchContent(systemPrompt: """
        \(systemPrompt)
        \(extraSystemPrompt)
        """, content: content)

        let stream = try await chatGPTService.send(content: content, summary: nil)
        isReceivingMessage = true
        do {
            for try await _ in stream {}
            isReceivingMessage = false
        } catch {
            isReceivingMessage = false
        }
    }

    public func stopReceivingMessage() async {
        await pluginController.stopResponding()
        await chatGPTService.stopReceivingMessage()
        isReceivingMessage = false
    }

    public func clearHistory() async {
        await pluginController.cancel()
        await chatGPTService.clearHistory()
        isReceivingMessage = false
    }

    public func resetPrompt() async {
        systemPrompt = UserDefaults.shared.value(for: \.defaultChatSystemPrompt)
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
        systemPrompt = newPrompt ?? UserDefaults.shared.value(for: \.defaultChatSystemPrompt)
    }

    public func mutateExtraSystemPrompt(_ newPrompt: String) {
        extraSystemPrompt = newPrompt
    }

    public func mutateHistory(_ mutator: @escaping (inout [ChatMessage]) -> Void) async {
        await chatGPTService.mutateHistory(mutator)
    }
}

