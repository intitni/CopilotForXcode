import ChatService
import Foundation
import SuggestionWidget

final class WidgetDataSource: SuggestionWidgetDataSource {
    static let shared = WidgetDataSource()

    private init() {}

    func suggestionForFile(at url: URL) async -> SuggestionProvider? {
        for workspace in await workspaces.values {
            if let filespace = await workspace.filespaces[url],
               let suggestion = await filespace.presentingSuggestion
            {
                return .init(
                    code: suggestion.text,
                    language: await filespace.language,
                    startLineIndex: suggestion.position.line,
                    suggestionCount: await filespace.suggestions.count,
                    currentSuggestionIndex: await filespace.suggestionIndex,
                    onSelectPreviousSuggestionTapped: {
                        Task { @ServiceActor in
                            let handler = PseudoCommandHandler()
                            await handler.presentPreviousSuggestion()
                        }
                    },
                    onSelectNextSuggestionTapped: {
                        Task { @ServiceActor in
                            let handler = PseudoCommandHandler()
                            await handler.presentNextSuggestion()
                        }
                    },
                    onRejectSuggestionTapped: {
                        Task { @ServiceActor in
                            let handler = PseudoCommandHandler()
                            await handler.rejectSuggestions()
                        }
                    },
                    onAcceptSuggestionTapped: {
                        Task { @ServiceActor in
                            let handler = PseudoCommandHandler()
                            await handler.acceptSuggestion()
                        }
                    }
                )
            }
        }
        return nil
    }

    func chatForFile(at url: URL) async -> ChatProvider? {
        for workspace in await workspaces.values {
            if let filespace = await workspace.filespaces[url],
               let service = await filespace.chatService
            {
                return .init(
                    service: service,
                    fileURL: url,
                    onCloseChat: { [weak filespace] in
                        Task { @ServiceActor [weak filespace] in
                            filespace?.chatService = nil
                        }
                    }
                )
            }
        }
        return nil
    }

    func chatServiceForFile(at url: URL) async -> ChatService? {
        for workspace in await workspaces.values {
            if let filespace = await workspace.filespaces[url] {
                return await filespace.chatService
            }
        }
        return nil
    }
}
