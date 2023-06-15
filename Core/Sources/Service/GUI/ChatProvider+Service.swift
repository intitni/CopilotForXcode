import ChatService
import Combine
import Foundation
import OpenAIService
import SuggestionWidget

extension ChatProvider {
    convenience init(
        service: ChatService,
        fileURL: URL,
        onCloseChat: @escaping () -> Void,
        onSwitchContext: @escaping () -> Void
    ) {
        self.init(pluginIdentifiers: service.allPluginCommands)

        let cancellable = service.objectWillChange.sink { [weak self] in
            guard let self else { return }
            Task { @MainActor in
                self.history = (await service.memory.history).map { message in
                    .init(
                        id: message.id,
                        isUser: message.role == .user,
                        text: message.summary ?? message.content
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
                do {
                    _ = try await service.send(content: message)
                } catch {
                    PresentInWindowSuggestionPresenter().presentError(error)
                }
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

        onClose = {
            Task {
                await service.stopReceivingMessage()
                onCloseChat()
            }
        }

        self.onSwitchContext = {
            onSwitchContext()
        }

        onDeleteMessage = { id in
            Task {
                await service.deleteMessage(id: id)
            }
        }

        onResendMessage = { id in
            Task {
                do {
                    try await service.resendMessage(id: id)
                } catch {
                    PresentInWindowSuggestionPresenter().presentError(error)
                }
            }
        }

        onResetPrompt = {
            Task {
                await service.resetPrompt()
            }
        }
        
        onRunCustomCommand = { command in
            Task {
                let commandHandler = PseudoCommandHandler()
                await commandHandler.handleCustomCommand(command)
            }
        }
        
        onSetAsExtraPrompt = { id in
            Task {
                await service.setMessageAsExtraPrompt(id: id)
            }
        }
    }
}

