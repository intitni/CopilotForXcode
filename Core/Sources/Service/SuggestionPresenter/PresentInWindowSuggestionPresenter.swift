import ChatService
import Foundation
import OpenAIService
import SuggestionModel
import SuggestionWidget

struct PresentInWindowSuggestionPresenter {
    func presentSuggestion(fileURL: URL) {
        Task { @MainActor in
            let controller = GraphicalUserInterfaceController.shared.widgetController
            controller.suggestCode()
        }
    }

    func discardSuggestion(fileURL: URL) {
        Task { @MainActor in
            let controller = GraphicalUserInterfaceController.shared.widgetController
            controller.discardSuggestion()
        }
    }

    func markAsProcessing(_ isProcessing: Bool) {
        Task { @MainActor in
            let controller = GraphicalUserInterfaceController.shared.widgetController
            controller.markAsProcessing(isProcessing)
        }
    }

    func presentError(_ error: Error) {
        if error is CancellationError { return }
        if let urlError = error as? URLError, urlError.code == URLError.cancelled { return }
        Task { @MainActor in
            let controller = GraphicalUserInterfaceController.shared.widgetController
            controller.presentError(error.localizedDescription)
        }
    }

    func presentErrorMessage(_ message: String) {
        Task { @MainActor in
            let controller = GraphicalUserInterfaceController.shared.widgetController
            controller.presentError(message)
        }
    }

    func closeChatRoom(fileURL: URL) {
        Task { @MainActor in
            let controller = GraphicalUserInterfaceController.shared.widgetController
            controller.closeChatRoom()
        }
    }

    func presentChatRoom(fileURL: URL) {
        Task { @MainActor in
            let controller = GraphicalUserInterfaceController.shared.widgetController
            controller.presentChatRoom()
        }
    }

    func presentPromptToCode(fileURL: URL) {
        Task { @MainActor in
            let controller = GraphicalUserInterfaceController.shared.widgetController
            controller.presentPromptToCode()
        }
    }

    func closePromptToCode(fileURL: URL) {
        Task { @MainActor in
            let controller = GraphicalUserInterfaceController.shared.widgetController
            controller.discardPromptToCode()
        }
    }
}

