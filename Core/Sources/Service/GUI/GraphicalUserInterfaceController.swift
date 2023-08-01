import AppKit
import ChatGPTChatTab
import ChatService
import ChatTab
import ComposableArchitecture
import Dependencies
import Environment
import Preferences
import PromptToCodeService
import SuggestionModel
import SuggestionWidget
import XcodeInspector

struct GUI: ReducerProtocol {
    struct State: Equatable {
        var suggestionWidgetState = WidgetFeature.State()

        var chatTabGroup: ChatPanelFeature.ChatTabGroup {
            get { suggestionWidgetState.chatPanelState.chatTapGroup }
            set { suggestionWidgetState.chatPanelState.chatTapGroup = newValue }
        }
    }

    enum Action {
        case openChatPanel(forceDetach: Bool)
        case createChatGPTChatTabIfNeeded
        case sendCustomCommandToActiveChat(CustomCommand)

        case suggestionWidget(WidgetFeature.Action)
    }

    var body: some ReducerProtocol<State, Action> {
        Scope(state: \.suggestionWidgetState, action: /Action.suggestionWidget) {
            WidgetFeature()
        }

        Scope(
            state: \.chatTabGroup,
            action: /Action.suggestionWidget .. /WidgetFeature.Action.chatPanel
        ) {
            Reduce { _, action in
                switch action {
                case let .createNewTapButtonClicked(kind):
                    let chatTap = kind?.builder.build() ?? ChatGPTChatTab()
                    return .run { send in
                        await send(.appendAndSelectTab(chatTap))
                    }

                default:
                    return .none
                }
            }
        }

        Reduce { state, action in
            switch action {
            case let .openChatPanel(forceDetach):
                return .run { send in
                    await send(
                        .suggestionWidget(.chatPanel(.presentChatPanel(forceDetach: forceDetach)))
                    )
                }

            case .createChatGPTChatTabIfNeeded:
                if state.chatTabGroup.tabs.contains(where: { $0 is ChatGPTChatTab }) {
                    return .none
                }
                let chatTab = ChatGPTChatTab()
                state.chatTabGroup.tabs.append(chatTab)
                return .none

            case let .sendCustomCommandToActiveChat(command):
                @Sendable func stopAndHandleCommand(_ tab: ChatGPTChatTab) async {
                    if tab.service.isReceivingMessage {
                        await tab.service.stopReceivingMessage()
                    }
                    try? await tab.service.handleCustomCommand(command)
                }

                if let activeTab = state.chatTabGroup.activeChatTab as? ChatGPTChatTab {
                    return .run { send in
                        await send(.openChatPanel(forceDetach: false))
                        await stopAndHandleCommand(activeTab)
                    }
                }

                if let chatTab = state.chatTabGroup.tabs.first(where: {
                    guard $0 is ChatGPTChatTab else { return false }
                    return true
                }) as? ChatGPTChatTab {
                    state.chatTabGroup.selectedTabId = chatTab.id
                    return .run { send in
                        await send(.openChatPanel(forceDetach: false))
                        await stopAndHandleCommand(chatTab)
                    }
                }
                let chatTab = ChatGPTChatTab()
                state.chatTabGroup.tabs.append(chatTab)
                return .run { send in
                    await send(.openChatPanel(forceDetach: false))
                    await stopAndHandleCommand(chatTab)
                }

            case .suggestionWidget:
                return .none
            }
        }
    }
}

@MainActor
public final class GraphicalUserInterfaceController {
    public static let shared = GraphicalUserInterfaceController()
    private let store: StoreOf<GUI>
    let widgetController: SuggestionWidgetController
    let widgetDataSource: WidgetDataSource
    let viewStore: ViewStoreOf<GUI>

    private init() {
        let suggestionDependency = SuggestionWidgetControllerDependency()
        let setupDependency: (inout DependencyValues) -> Void = { dependencies in
            dependencies.suggestionWidgetControllerDependency = suggestionDependency
            dependencies.suggestionWidgetUserDefaultsObservers = .init()
            dependencies.chatTabBuilderCollection = {
                ChatTabFactory.chatTabBuilderCollection
            }
        }
        let store = StoreOf<GUI>(
            initialState: .init(),
            reducer: GUI(),
            prepareDependencies: setupDependency
        )
        self.store = store
        viewStore = ViewStore(store)
        widgetDataSource = .init()

        widgetController = SuggestionWidgetController(
            store: store.scope(
                state: \.suggestionWidgetState,
                action: GUI.Action.suggestionWidget
            ),
            dependency: suggestionDependency
        )

        suggestionDependency.suggestionWidgetDataSource = widgetDataSource
        suggestionDependency.onOpenChatClicked = { [weak self] in
            Task { [weak self] in
                await self?.viewStore.send(.createChatGPTChatTabIfNeeded).finish()
                self?.viewStore.send(.openChatPanel(forceDetach: false))
            }
        }
        suggestionDependency.onCustomCommandClicked = { command in
            Task {
                let commandHandler = PseudoCommandHandler()
                await commandHandler.handleCustomCommand(command)
            }
        }
    }

    public func openGlobalChat() {
        Task {
            await self.viewStore.send(.createChatGPTChatTabIfNeeded).finish()
            viewStore.send(.openChatPanel(forceDetach: true))
        }
    }
}

#if canImport(ProChatTabs)
import ProChatTabs

enum ChatTabFactory {
    static var chatTabBuilderCollection: [ChatTabBuilderCollection] {
        func folderIfNeeded(
            _ builders: [any ChatTabBuilder],
            title: String
        ) -> ChatTabBuilderCollection? {
            if builders.count > 1 {
                return .folder(title: title, kinds: builders.map(ChatTabKind.init))
            }
            if let first = builders.first { return .kind(ChatTabKind(first)) }
            return nil
        }

        let collection = [
            folderIfNeeded(ChatGPTChatTab.chatBuilders(), title: ChatGPTChatTab.name),
            folderIfNeeded(BrowserChatTab.chatBuilders(externalDependency: .init(
                getEditorContent: {
                    guard let editor = XcodeInspector.shared.focusedEditor else {
                        return .init(selectedText: "", language: "", fileContent: "")
                    }
                    let content = editor.content
                    return .init(
                        selectedText: content.selectedContent,
                        language: languageIdentifierFromFileURL(
                            XcodeInspector.shared
                                .activeDocumentURL
                        )
                        .rawValue,
                        fileContent: content.content
                    )
                },
                handleCustomCommand: { command, prompt in
                    switch command.feature {
                    case let .chatWithSelection(extraSystemPrompt, _, useExtraSystemPrompt):
                        let service = ChatService()
                        return try await service.processMessage(
                            systemPrompt: nil,
                            extraSystemPrompt: (useExtraSystemPrompt ?? false) ? extraSystemPrompt :
                                nil,
                            prompt: prompt
                        )
                    case let .customChat(systemPrompt, _):
                        let service = ChatService()
                        return try await service.processMessage(
                            systemPrompt: systemPrompt,
                            extraSystemPrompt: nil,
                            prompt: prompt
                        )
                    case let .singleRoundDialog(
                        systemPrompt,
                        overwriteSystemPrompt,
                        _,
                        _
                    ):
                        let service = ChatService()
                        return try await service.handleSingleRoundDialogCommand(
                            systemPrompt: systemPrompt,
                            overwriteSystemPrompt: overwriteSystemPrompt ?? false,
                            prompt: prompt
                        )
                    case let .promptToCode(extraSystemPrompt, instruction, _, _):
                        let service = PromptToCodeService(
                            code: prompt,
                            selectionRange: .outOfScope,
                            language: .plaintext,
                            identSize: 4,
                            usesTabsForIndentation: true,
                            projectRootURL: .init(fileURLWithPath: "/"),
                            fileURL: .init(fileURLWithPath: "/"),
                            allCode: prompt,
                            extraSystemPrompt: extraSystemPrompt,
                            generateDescriptionRequirement: false
                        )
                        try await service.modifyCode(prompt: instruction ?? "Modify content.")
                        return service.code
                    }
                }
            )), title: BrowserChatTab.name),
        ].compactMap { $0 }

        return collection
    }
}

#else

enum ChatTabFactory {
    static var chatTabBuilderCollection: [ChatTabBuilderCollection] {
        func folderIfNeeded(
            _ builders: [any ChatTabBuilder],
            title: String
        ) -> ChatTabBuilderCollection? {
            if builders.count > 1 {
                return .folder(title: title, kinds: builders.map(ChatTabKind.init))
            }
            if let first = builders.first { return .kind(ChatTabKind(first)) }
            return nil
        }

        return [
            folderIfNeeded(ChatGPTChatTab.chatBuilders(), title: ChatGPTChatTab.name),
        ].compactMap { $0 }
    }
}

#endif

