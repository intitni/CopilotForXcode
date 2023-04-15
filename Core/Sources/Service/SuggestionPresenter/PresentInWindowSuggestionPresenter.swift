import ChatService
import CopilotModel
import Foundation
import OpenAIService
import SuggestionWidget

struct PresentInWindowSuggestionPresenter {
    func presentSuggestion(fileURL: URL) {
        Task { @MainActor in
            let controller = GraphicalUserInterfaceController.shared.suggestionWidget
            controller.suggestCode(fileURL: fileURL)
        }
    }

    func discardSuggestion(fileURL: URL) {
        Task { @MainActor in
            let controller = GraphicalUserInterfaceController.shared.suggestionWidget
            controller.discardSuggestion(fileURL: fileURL)
        }
    }

    func markAsProcessing(_ isProcessing: Bool) {
        Task { @MainActor in
            let controller = GraphicalUserInterfaceController.shared.suggestionWidget
            controller.markAsProcessing(isProcessing)
        }
    }

    func presentError(_ error: Error) {
        if error is CancellationError { return }
        Task { @MainActor in
            let controller = GraphicalUserInterfaceController.shared.suggestionWidget
            controller.presentError(error.localizedDescription)
        }
    }

    func presentErrorMessage(_ message: String) {
        Task { @MainActor in
            let controller = GraphicalUserInterfaceController.shared.suggestionWidget
            controller.presentError(message)
        }
    }

    func closeChatRoom(fileURL: URL) {
        Task { @MainActor in
            let controller = GraphicalUserInterfaceController.shared.suggestionWidget
            controller.closeChatRoom(fileURL: fileURL)
        }
    }

    func presentChatRoom(fileURL: URL) {
        Task { @MainActor in
            let controller = GraphicalUserInterfaceController.shared.suggestionWidget
            controller.presentChatRoom(fileURL: fileURL)
        }
    }
    
    func presentPromptToCode(fileURL: URL) {
        Task { @MainActor in
            let controller = GraphicalUserInterfaceController.shared.suggestionWidget
            controller.presentPromptToCode(fileURL: fileURL)
        }
    }
    
    func closePromptToCode(fileURL: URL) {
        Task { @MainActor in
            let controller = GraphicalUserInterfaceController.shared.suggestionWidget
            controller.discardPromptToCode(fileURL: fileURL)
        }
    }
}
