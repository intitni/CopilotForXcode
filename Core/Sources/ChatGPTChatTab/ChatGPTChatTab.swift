import ChatService
import ChatTab
import Combine
import ComposableArchitecture
import Foundation
import OpenAIService
import Preferences
import SwiftUI

/// A chat tab that provides a context aware chat bot, powered by ChatGPT.
public class ChatGPTChatTab: ChatTab {
    public static var name: String { "Chat" }

    public let service: ChatService
    public let provider: ChatProvider
    private var cancellable = Set<AnyCancellable>()

    struct RestorableState: Codable {
        var history: [OpenAIService.ChatMessage]
        var configuration: OverridingChatGPTConfiguration.Overriding
        var systemPrompt: String
        var extraSystemPrompt: String
    }

    struct Builder: ChatTabBuilder {
        var title: String
        var customCommand: CustomCommand?
        var afterBuild: (ChatGPTChatTab) async -> Void = { _ in }

        func build(store: StoreOf<ChatTabItem>) async -> (any ChatTab)? {
            let tab = ChatGPTChatTab(store: store)
            if let customCommand {
                try? await tab.service.handleCustomCommand(customCommand)
            }
            await afterBuild(tab)
            return tab
        }
    }

    public func buildView() -> any View {
        ChatPanel(chat: provider)
    }

    public func buildTabItem() -> any View {
        ChatContextMenu(chat: provider)
    }

    public func restorableState() async -> Data {
        let state = RestorableState(
            history: await service.memory.history,
            configuration: service.configuration.overriding,
            systemPrompt: service.systemPrompt,
            extraSystemPrompt: service.extraSystemPrompt
        )
        return (try? JSONEncoder().encode(state)) ?? Data()
    }

    public static func restore(
        from data: Data,
        externalDependency: Void
    ) async throws -> any ChatTabBuilder {
        let state = try JSONDecoder().decode(RestorableState.self, from: data)
        let builder = Builder(title: "Chat") { @MainActor tab in
            tab.service.configuration.overriding = state.configuration
            tab.service.mutateSystemPrompt(state.systemPrompt)
            tab.service.mutateExtraSystemPrompt(state.extraSystemPrompt)
            await tab.service.memory.mutateHistory { history in
                history = state.history
            }
        }
        return builder
    }

    public static func chatBuilders(externalDependency: Void) -> [ChatTabBuilder] {
        let customCommands = UserDefaults.shared.value(for: \.customCommands).compactMap {
            command in
            if case .customChat = command.feature {
                return Builder(title: command.name, customCommand: command)
            }
            return nil
        }

        return [Builder(title: "New Chat", customCommand: nil)] + customCommands
    }

    public init(service: ChatService = .init(), store: StoreOf<ChatTabItem>) {
        self.service = service
        provider = .init(service: service)
        super.init(store: store)
    }

    public func start() {
        chatTabViewStore.send(.updateTitle("Chat"))
        
        service.$systemPrompt.removeDuplicates().sink { _ in
            Task { @MainActor [weak self] in
                self?.chatTabViewStore.send(.tabContentUpdated)
            }
        }.store(in: &cancellable)
        
        service.$extraSystemPrompt.removeDuplicates().sink { _ in
            Task { @MainActor [weak self] in
                self?.chatTabViewStore.send(.tabContentUpdated)
            }
        }.store(in: &cancellable)
        
        provider.$history.sink { [weak self] _ in
            Task { @MainActor [weak self] in
                if let title = self?.provider.title {
                    self?.chatTabViewStore.send(.updateTitle(title))
                }
                self?.chatTabViewStore.send(.tabContentUpdated)
            }
        }.store(in: &cancellable)
    }
}

extension ChatProvider {
    convenience init(service: ChatService) {
        self.init(pluginIdentifiers: service.allPluginCommands)

        let cancellable = service.objectWillChange.sink { [weak self] in
            guard let self else { return }
            Task { @MainActor in
                self.history = (await service.memory.history).map { message in
                    .init(
                        id: message.id,
                        role: {
                            switch message.role {
                            case .system: return .ignored
                            case .user: return .user
                            case .assistant:
                                if let text = message.summary ?? message.content, !text.isEmpty {
                                    return .assistant
                                }
                                return .ignored
                            case .function: return .function
                            }
                        }(),
                        text: message.summary ?? message.content ?? ""
                    )
                }
                self.isReceivingMessage = service.isReceivingMessage
                self.systemPrompt = service.systemPrompt
                self.extraSystemPrompt = service.extraSystemPrompt
            }
        }

        service.objectWillChange.send()

        onMessageSend = { [cancellable] message in
            _ = cancellable
            Task {
                try await service.send(content: message)
            }
        }
        onStop = {
            Task {
                await service.stopReceivingMessage()
            }
        }

        onClear = {
            Task {
                await service.clearHistory()
            }
        }

        onDeleteMessage = { id in
            Task {
                await service.deleteMessage(id: id)
            }
        }

        onResendMessage = { id in
            Task {
                try await service.resendMessage(id: id)
            }
        }

        onResetPrompt = {
            Task {
                await service.resetPrompt()
            }
        }

        onRunCustomCommand = { command in
            Task {
                try await service.handleCustomCommand(command)
            }
        }

        onSetAsExtraPrompt = { id in
            Task {
                await service.setMessageAsExtraPrompt(id: id)
            }
        }
    }
}

