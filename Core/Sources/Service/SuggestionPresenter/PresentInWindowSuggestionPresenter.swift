import CopilotModel
import Foundation

struct PresentInWindowSuggestionPresenter {
    func presentSuggestion(
        _ suggestion: CopilotCompletion,
        lines: [String],
        language: String,
        fileURL: URL,
        currentSuggestionIndex: Int,
        suggestionCount: Int
    ) {
        Task { @MainActor in
            let controller = GraphicalUserInterfaceController.shared.suggestionWidget
            controller.suggestCode(
                suggestion.text,
                language: language,
                startLineIndex: suggestion.position.line,
                fileURL: fileURL,
                currentSuggestionIndex: currentSuggestionIndex,
                suggestionCount: suggestionCount
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
    
    func presentError(_ error: Error) {
        Task { @MainActor in
            let controller = GraphicalUserInterfaceController.shared.suggestionWidget
            controller.presentError(error.localizedDescription)
        }
    }
}
