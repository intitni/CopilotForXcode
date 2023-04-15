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
            suggestionWidget.dataSource = WidgetDataSource.shared
            suggestionWidget.onOpenChatClicked = {
                Task {
                    let fileURL = try await Environment.fetchCurrentFileURL()
                    await WidgetDataSource.shared.createChatIfNeeded(for: fileURL)
                    let presenter = PresentInWindowSuggestionPresenter()
                    presenter.presentChatRoom(fileURL: fileURL)
                }
            }
        }
    }
}
