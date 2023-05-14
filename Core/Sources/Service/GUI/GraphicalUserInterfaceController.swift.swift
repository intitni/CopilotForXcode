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
                    let commandHandler = WindowBaseCommandHandler()
                    _ = try await commandHandler.chatWithSelection(editor: .init(
                        content: "",
                        lines: [],
                        uti: "",
                        cursorPosition: .outOfScope,
                        selections: [],
                        tabSize: 0,
                        indentSize: 0,
                        usesTabsForIndentation: false
                    ))
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
