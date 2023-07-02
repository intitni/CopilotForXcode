import ChatService
import Foundation
import OpenAIService
import SuggestionModel
import SuggestionWidget

struct PresentInWindowSuggestionPresenter {
    func presentSuggestion(fileURL: URL) {
        Task { @MainActor in
            let controller = GraphicalUserInterfaceController.shared.suggestionWidget
            controller.suggestCode()
        }
    }

    func discardSuggestion(fileURL: URL) {
        Task { @MainActor in
            let controller = GraphicalUserInterfaceController.shared.suggestionWidget
            controller.discardSuggestion()
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
        if let urlError = error as? URLError, urlError.code == URLError.cancelled { return }
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
            controller.closeChatRoom()
        }
    }

    func presentChatRoom(fileURL: URL) {
        Task { @MainActor in
            let controller = GraphicalUserInterfaceController.shared.suggestionWidget
            controller.presentChatRoom()
        }
    }

    func presentPromptToCode(fileURL: URL) {
        Task { @MainActor in
            let controller = GraphicalUserInterfaceController.shared.suggestionWidget
            controller.presentPromptToCode()
        }
    }

    func closePromptToCode(fileURL: URL) {
        Task { @MainActor in
            let controller = GraphicalUserInterfaceController.shared.suggestionWidget
            controller.discardPromptToCode()
        }
    }
}

