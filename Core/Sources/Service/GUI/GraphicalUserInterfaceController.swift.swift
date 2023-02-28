import AppKit
import SuggestionWidget

@MainActor
public final class GraphicalUserInterfaceController {
    public nonisolated static let shared = GraphicalUserInterfaceController()
    nonisolated let realtimeSuggestionIndicatorController = RealtimeSuggestionIndicatorController()
    nonisolated let suggestionWidget = SuggestionWidgetController()
    private nonisolated init() {}
}
