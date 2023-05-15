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
            suggestionWidget.onOpenChatClicked = { [weak self] in
                Task {
                    let uri = try await Environment.fetchFocusedElementURI()
                    let dataSource = WidgetDataSource.shared
                    await dataSource.createChatIfNeeded(for: uri)
                    self?.suggestionWidget.presentChatRoom(fileURL: uri)
                }
            }
            suggestionWidget.onCustomCommandClicked = { command in
                Task {
                    let commandHandler = PseudoCommandHandler()
                    await commandHandler.handleCustomCommand(command)
                }
            }
        }
    }
    
    public func openGlobalChat() {
        UserDefaults.shared.set(true, for: \.useGlobalChat)
        let dataSource = WidgetDataSource.shared
        let fakeFileURL = URL(fileURLWithPath: "/")
        Task {
            await dataSource.createChatIfNeeded(for: fakeFileURL)
            suggestionWidget.presentDetachedGlobalChat()
        }
    }
}
