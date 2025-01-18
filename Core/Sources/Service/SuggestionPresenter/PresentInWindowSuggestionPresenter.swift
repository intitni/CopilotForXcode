import ChatService
import Foundation
import OpenAIService
import SuggestionBasic
import SuggestionWidget

struct PresentInWindowSuggestionPresenter {
    func markAsProcessing(_ isProcessing: Bool) {
        Task { @MainActor in
            let controller = Service.shared.guiController.widgetController
            controller.markAsProcessing(isProcessing)
        }
    }
}

