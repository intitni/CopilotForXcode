import ChatService
import Foundation
import OpenAIService
import SuggestionWidget

final class WidgetDataSource {
    static let shared = WidgetDataSource()

    var globalChat: ChatService?
    var chats = [URL: ChatService]()

    private init() {}

    @discardableResult
    func createChatIfNeeded(for url: URL) -> ChatService {
        let useGlobalChat = UserDefaults.shared.value(for: \.useGlobalChat)
        let chat: ChatService
        if useGlobalChat {
            chat = globalChat ?? ChatService(chatGPTService: ChatGPTService())
            globalChat = chat
        } else {
            chat = chats[url] ?? ChatService(chatGPTService: ChatGPTService())
            chats[url] = chat
        }
        return chat
    }
}

extension WidgetDataSource: SuggestionWidgetDataSource {
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
        let useGlobalChat = UserDefaults.shared.value(for: \.useGlobalChat)
        let buildChatProvider = { (service: ChatService) in
            ChatProvider(
                service: service,
                fileURL: url,
                onCloseChat: { [weak self] in
                    if UserDefaults.shared.value(for: \.useGlobalChat) {
                        self?.globalChat = nil
                    } else {
                        self?.chats[url] = nil
                    }
                    let presenter = PresentInWindowSuggestionPresenter()
                    presenter.closeChatRoom(fileURL: url)
                },
                onSwitchContext: { [weak self] in
                    let useGlobalChat = UserDefaults.shared.value(for: \.useGlobalChat)
                    UserDefaults.shared.set(!useGlobalChat, for: \.useGlobalChat)
                    self?.createChatIfNeeded(for: url)
                    let presenter = PresentInWindowSuggestionPresenter()
                    presenter.presentChatRoom(fileURL: url)
                }
            )
        }

        if useGlobalChat {
            if let globalChat {
                return buildChatProvider(globalChat)
            }
        } else {
            if let service = chats[url] {
                return buildChatProvider(service)
            }
        }

        return nil
    }
}
