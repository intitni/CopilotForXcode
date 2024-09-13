import ChatService
import Foundation
import OpenAIService
import SuggestionBasic
import SuggestionWidget

struct PresentInWindowSuggestionPresenter {
    func presentSuggestion(fileURL: URL) {
        Task { @MainActor in
            let controller = Service.shared.guiController.widgetController
            controller.suggestCode()
        }
    }

    func discardSuggestion(fileURL: URL) {
        Task { @MainActor in
            let controller = Service.shared.guiController.widgetController
            controller.discardSuggestion()
        }
    }

    func markAsProcessing(_ isProcessing: Bool) {
        Task { @MainActor in
            let controller = Service.shared.guiController.widgetController
            controller.markAsProcessing(isProcessing)
        }
    }

    func presentError(_ error: Error) {
        if error is CancellationError { return }
        if let urlError = error as? URLError, urlError.code == URLError.cancelled { return }
        Task { @MainActor in
            let controller = Service.shared.guiController.widgetController
            controller.presentError(error.localizedDescription)
        }
    }

    func presentErrorMessage(_ message: String) {
        Task { @MainActor in
            let controller = Service.shared.guiController.widgetController
            controller.presentError(message)
        }
    }

    func presentChatRoom(fileURL: URL) {
        Task { @MainActor in
            let controller = Service.shared.guiController
            controller.store.send(.openChatPanel(forceDetach: false, activateThisApp: true))
        }
    }
}

