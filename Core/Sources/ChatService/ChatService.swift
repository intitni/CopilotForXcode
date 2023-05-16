import ChatPlugins
import Combine
import Foundation
import OpenAIService

public final class ChatService: ObservableObject {
    public let chatGPTService: any ChatGPTServiceType
    let pluginController: ChatPluginController
    var runningPlugin: ChatPlugin?
    var cancellable = Set<AnyCancellable>()

    public init<T: ChatGPTServiceType>(chatGPTService: T) {
        self.chatGPTService = chatGPTService
        pluginController = ChatPluginController(
            chatGPTService: chatGPTService,
            plugins:
            TerminalChatPlugin.self,
            AITerminalChatPlugin.self
        )

        chatGPTService.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }.store(in: &cancellable)
    }

    public func send(content: String) async throws {
        let handledInPlugin = try await pluginController.handleContent(content)
        if handledInPlugin { return }
        
        _ = try await chatGPTService.send(content: content, summary: nil)
    }

    public func stopReceivingMessage() async {
        if let runningPlugin {
            await runningPlugin.stopResponding()
        }
        await chatGPTService.stopReceivingMessage()
    }

    public func clearHistory() async {
        if let runningPlugin {
            await runningPlugin.cancel()
        }
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

    public func mutateSystemPrompt(_ newPrompt: String) async {
        await chatGPTService.mutateSystemPrompt(newPrompt)
    }
}
