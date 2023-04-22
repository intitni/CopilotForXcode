import ChatService
import CopilotModel
import CopilotService
import Foundation
import OpenAIService
import PromptToCodeService
import SuggestionWidget

@ServiceActor
final class WidgetDataSource {
    static let shared = WidgetDataSource()

    final class Chat {
        let chatService: ChatService
        let provider: ChatProvider
        public init(chatService: ChatService, provider: ChatProvider) {
            self.chatService = chatService
            self.provider = provider
        }
    }

    final class PromptToCode {
        let promptToCodeService: PromptToCodeService
        let provider: PromptToCodeProvider
        public init(
            promptToCodeService: PromptToCodeService,
            provider: PromptToCodeProvider
        ) {
            self.promptToCodeService = promptToCodeService
            self.provider = provider
        }
    }

    private(set) var globalChat: Chat?
    private(set) var chats = [URL: Chat]()
    private(set) var promptToCodes = [URL: PromptToCode]()

    private init() {}

    @discardableResult
    func createChatIfNeeded(for url: URL) -> ChatService {
        let build = {
            let service = ChatService(chatGPTService: ChatGPTService())
            let provider = ChatProvider(
                service: service,
                fileURL: url,
                onCloseChat: { [weak self] in
                    if UserDefaults.shared.value(for: \.useGlobalChat) {
                        self?.globalChat = nil
                    } else {
                        self?.removeChat(for: url)
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
            return Chat(chatService: service, provider: provider)
        }

        let useGlobalChat = UserDefaults.shared.value(for: \.useGlobalChat)
        if useGlobalChat {
            if let globalChat {
                return globalChat.chatService
            }
            let newChat = build()
            globalChat = newChat
            return newChat.chatService
        } else {
            if let chat = chats[url] {
                return chat.chatService
            }
            let newChat = build()
            chats[url] = newChat
            return newChat.chatService
        }
    }

    @discardableResult
    func createPromptToCode(
        for url: URL,
        projectURL: URL,
        selectedCode: String,
        allCode: String,
        selectionRange: CursorRange,
        language: CopilotLanguage,
        identSize: Int = 4,
        usesTabsForIndentation: Bool = false,
        extraSystemPrompt: String?,
        name: String?
    ) async -> PromptToCodeService {
        let build = {
            let service = PromptToCodeService(
                code: selectedCode,
                selectionRange: selectionRange,
                language: language,
                identSize: identSize,
                usesTabsForIndentation: usesTabsForIndentation,
                projectRootURL: projectURL,
                fileURL: url,
                allCode: allCode,
                extraSystemPrompt: extraSystemPrompt
            )
            let provider = PromptToCodeProvider(
                service: service,
                name: name,
                onClosePromptToCode: { [weak self] in
                    self?.removePromptToCode(for: url)
                    let presenter = PresentInWindowSuggestionPresenter()
                    presenter.closePromptToCode(fileURL: url)
                }
            )
            return PromptToCode(promptToCodeService: service, provider: provider)
        }

        let newPromptToCode = build()
        promptToCodes[url] = newPromptToCode
        return newPromptToCode.promptToCodeService
    }

    func removeChat(for url: URL) {
        chats[url] = nil
    }

    func removePromptToCode(for url: URL) {
        promptToCodes[url] = nil
    }

    func cleanup(for url: URL) {
        removeChat(for: url)
        removePromptToCode(for: url)
    }
}

extension WidgetDataSource: SuggestionWidgetDataSource {
    func suggestionForFile(at url: URL) async -> SuggestionProvider? {
        for workspace in workspaces.values {
            if let filespace = workspace.filespaces[url],
               let suggestion = filespace.presentingSuggestion
            {
                return .init(
                    code: suggestion.text,
                    language: filespace.language,
                    startLineIndex: suggestion.position.line,
                    suggestionCount: filespace.suggestions.count,
                    currentSuggestionIndex: filespace.suggestionIndex,
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
        if useGlobalChat {
            if let globalChat {
                return globalChat.provider
            }
        } else {
            if let chat = chats[url] {
                return chat.provider
            }
        }

        return nil
    }

    func promptToCodeForFile(at url: URL) async -> PromptToCodeProvider? {
        return promptToCodes[url]?.provider
    }
}
