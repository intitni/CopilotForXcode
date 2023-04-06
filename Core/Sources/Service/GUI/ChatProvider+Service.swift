import ChatService
import Foundation
import OpenAIService
import SuggestionWidget

extension ChatProvider {
    convenience init(service: ChatService, fileURL: URL, onCloseChat: @escaping () -> Void) {
        self.init()
        let cancellable = service.objectWillChange.sink { [weak self] in
            guard let self else { return }
            Task { @MainActor in
                self.history = (await service.chatGPTService.history).map { message in
                    .init(
                        id: message.id,
                        isUser: message.role == .user,
                        text: message.summary ?? message.content
                    )
                }
                self.isReceivingMessage = await service.chatGPTService.isReceivingMessage
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
                PresentInWindowSuggestionPresenter().closeChatRoom(fileURL: fileURL)
                onCloseChat()
            }
        }
    }
}
