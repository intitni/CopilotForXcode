import ChatContextCollector
import ChatService
import ChatTab
import CodableWrappers
import Combine
import ComposableArchitecture
import DebounceFunction
import Foundation
import OpenAIService
import Preferences
import SwiftUI

/// A chat tab that provides a context aware chat bot, powered by ChatGPT.
public class ChatGPTChatTab: ChatTab {
    public static var name: String { "Chat" }

    public let service: ChatService
    let chat: StoreOf<Chat>
    private var cancellable = Set<AnyCancellable>()
    private var observer = NSObject()
    private let updateContentDebounce = DebounceRunner(duration: 0.5)

    struct RestorableState: Codable {
        var history: [OpenAIService.ChatMessage]
        var configuration: OverridingChatGPTConfiguration.Overriding
        var systemPrompt: String
        var extraSystemPrompt: String
        var defaultScopes: Set<ChatContext.Scope>?
    }

    struct Builder: ChatTabBuilder {
        var title: String
        var customCommand: CustomCommand?
        var afterBuild: (ChatGPTChatTab) async -> Void = { _ in }

        func build(store: StoreOf<ChatTabItem>) async -> (any ChatTab)? {
            let tab = await ChatGPTChatTab(store: store)
            if let customCommand {
                try? await tab.service.handleCustomCommand(customCommand)
            }
            await afterBuild(tab)
            return tab
        }
    }

    public func buildView() -> any View {
        ChatPanel(chat: chat)
    }

    public func buildTabItem() -> any View {
        ChatTabItemView(chat: chat)
    }

    public func buildIcon() -> any View {
        WithPerceptionTracking {
            if self.chat.isReceivingMessage {
                Image(systemName: "ellipsis.message")
            } else {
                Image(systemName: "message")
            }
        }
    }

    public func buildMenu() -> any View {
        ChatContextMenu(store: chat.scope(state: \.chatMenu, action: \.chatMenu))
    }

    public func restorableState() async -> Data {
        let state = RestorableState(
            history: await service.memory.history,
            configuration: service.configuration.overriding,
            systemPrompt: service.systemPrompt,
            extraSystemPrompt: service.extraSystemPrompt,
            defaultScopes: service.defaultScopes
        )
        return (try? JSONEncoder().encode(state)) ?? Data()
    }

    public static func restore(from data: Data) async throws -> any ChatTabBuilder {
        let state = try JSONDecoder().decode(RestorableState.self, from: data)
        let builder = Builder(title: "Chat") { @MainActor tab in
            tab.service.configuration.overriding = state.configuration
            tab.service.mutateSystemPrompt(state.systemPrompt)
            tab.service.mutateExtraSystemPrompt(state.extraSystemPrompt)
            if let scopes = state.defaultScopes {
                tab.service.defaultScopes = scopes
            }
            await tab.service.memory.mutateHistory { history in
                history = state.history
            }
            tab.chat.send(.refresh)
        }
        return builder
    }

    public static func chatBuilders() -> [ChatTabBuilder] {
        let customCommands = UserDefaults.shared.value(for: \.customCommands).compactMap {
            command in
            if case .customChat = command.feature {
                return Builder(title: command.name, customCommand: command)
            }
            return nil
        }

        return [Builder(title: "New Chat", customCommand: nil)] + customCommands
    }
    
    public static func defaultBuilder() -> ChatTabBuilder {
        Builder(title: "New Chat", customCommand: nil)
    }

    @MainActor
    public init(service: ChatService = .init(), store: StoreOf<ChatTabItem>) {
        self.service = service
        chat = .init(initialState: .init(), reducer: { Chat(service: service) })
        super.init(store: store)
    }

    public func start() {
        observer = .init()
        cancellable = []

        chatTabStore.send(.updateTitle("Chat"))

        service.$systemPrompt.removeDuplicates().sink { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.chatTabStore.send(.tabContentUpdated)
            }
        }.store(in: &cancellable)

        service.$extraSystemPrompt.removeDuplicates().sink { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.chatTabStore.send(.tabContentUpdated)
            }
        }.store(in: &cancellable)

        do {
            var lastTrigger = -1
            observer.observe { [weak self] in
                guard let self else { return }
                let trigger = chatTabStore.focusTrigger
                guard lastTrigger != trigger else { return }
                lastTrigger = trigger
                Task { @MainActor [weak self] in
                    self?.chat.send(.focusOnTextField)
                }
            }
        }

        do {
            var lastTitle = ""
            observer.observe { [weak self] in
                guard let self else { return }
                let title = self.chatTabStore.state.title
                guard lastTitle != title else { return }
                lastTitle = title
                Task { @MainActor [weak self] in
                    self?.chatTabStore.send(.updateTitle(title))
                }
            }
        }

        observer.observe { [weak self] in
            guard let self else { return }
            _ = chat.history
            _ = chat.title
            _ = chat.isReceivingMessage
            Task {
                await self.updateContentDebounce.debounce { @MainActor [weak self] in
                    self?.chatTabStore.send(.tabContentUpdated)
                }
            }
        }
    }
}

