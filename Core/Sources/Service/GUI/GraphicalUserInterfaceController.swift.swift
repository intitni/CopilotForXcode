import AppKit

@MainActor
public final class GraphicalUserInterfaceController {
    public nonisolated static let shared = GraphicalUserInterfaceController()
    nonisolated let realtimeSuggestionIndicatorController = RealtimeSuggestionIndicatorController()
    nonisolated let suggestionPanelController = SuggestionPanelController()
    private nonisolated init() {}
}
