import AppKit
import Environment
import SuggestionWidget

@MainActor
public final class GraphicalUserInterfaceController {
    public nonisolated static let shared = GraphicalUserInterfaceController()
    nonisolated let realtimeSuggestionIndicatorController = RealtimeSuggestionIndicatorController()
    nonisolated let suggestionWidget = SuggestionWidgetController()
    private nonisolated init() {
        Task { @MainActor in
            suggestionWidget.onNextButtonTapped = {
                Task { @ServiceActor in
                    let handler = PseudoCommandHandler()
                    await handler.presentNextSuggestion()
                }
            }

            suggestionWidget.onPreviousButtonTapped = {
                Task { @ServiceActor in
                    let handler = PseudoCommandHandler()
                    await handler.presentPreviousSuggestion()
                }
            }

            suggestionWidget.onRejectButtonTapped = {
                Task { @ServiceActor in
                    let handler = PseudoCommandHandler()
                    await handler.rejectSuggestions()
                }
            }

            suggestionWidget.onAcceptButtonTapped = {
                Task { @ServiceActor in
                    let handler = PseudoCommandHandler()
                    await handler.acceptSuggestion()
                }
            }
        }
    }
}
