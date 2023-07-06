import ChatService
import Combine
import Foundation
import SwiftUI

/// A chat tab that provides a context aware chat bot, powered by ChatGPT.
public class ChatGPTChatTab: ChatTab {
    public let service: ChatService
    public let provider: ChatProvider
    private var cancellable = Set<AnyCancellable>()

    public func buildView() -> any View {
        ChatPanel(chat: provider)
    }

    public init(service: ChatService = .init()) {
        self.service = service
        provider = .init(service: service)
        super.init(id: "Chat-" + provider.id.uuidString, title: "Chat")
        
        provider.$history.sink { [weak self] _ in
            if let title = self?.provider.title {
                self?.title = title
            }
        }.store(in: &cancellable)
    }
}

extension ChatProvider {
    convenience init(service: ChatService) {
        self.init(pluginIdentifiers: service.allPluginCommands)

        let cancellable = service.objectWillChange.sink { [weak self] in
            guard let self else { return }
            Task { @MainActor in
                self.history = (await service.memory.history).map { message in
                    .init(
                        id: message.id,
                        role: {
                            switch message.role {
                            case .system: return .ignored
                            case .user: return .user
                            case .assistant:
                                if let text = message.summary ?? message.content, !text.isEmpty {
                                    return .assistant
                                }
                                return .ignored
                            case .function: return .function
                            }
                        }(),
                        text: message.summary ?? message.content ?? ""
                    )
                }
                self.isReceivingMessage = service.isReceivingMessage
                self.systemPrompt = service.systemPrompt
                self.extraSystemPrompt = service.extraSystemPrompt
            }
        }

        service.objectWillChange.send()

        onMessageSend = { [cancellable] message in
            _ = cancellable
            Task {
                try await service.send(content: message)
            }
        }
        onStop = {
            Task {
                await service.stopReceivingMessage()
            }
        }

        onClear = {
            Task {
                await service.clearHistory()
            }
        }

        onDeleteMessage = { id in
            Task {
                await service.deleteMessage(id: id)
            }
        }

        onResendMessage = { id in
            Task {
                try await service.resendMessage(id: id)
            }
        }

        onResetPrompt = {
            Task {
                await service.resetPrompt()
            }
        }

        onRunCustomCommand = { command in
            Task {
                try await service.handleCustomCommand(command)
            }
        }

        onSetAsExtraPrompt = { id in
            Task {
                await service.setMessageAsExtraPrompt(id: id)
            }
        }
    }
}

