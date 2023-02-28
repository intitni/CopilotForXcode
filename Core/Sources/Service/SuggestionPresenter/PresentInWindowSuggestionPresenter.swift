import CopilotModel
import Foundation

struct PresentInWindowSuggestionPresenter {
    func presentSuggestion(_ suggestion: CopilotCompletion, lines: [String], fileURL: URL) {
        Task { @MainActor in
            let controller = GraphicalUserInterfaceController.shared.suggestionWidget
            controller.suggestCode(
                suggestion.text,
                startLineIndex: suggestion.position.line,
                fileURL: fileURL
            )
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
}
