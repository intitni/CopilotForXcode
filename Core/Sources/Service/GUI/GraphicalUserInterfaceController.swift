import AppKit
import ChatGPTChatTab
import ChatTab
import ComposableArchitecture
import Dependencies
import Environment
import Preferences
import SuggestionWidget

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
                    guard let builder = kind?.builder else {
                        let chatTap = ChatGPTChatTab()
                        return .run { send in
                            await send(.appendAndSelectTab(chatTap))
                        }
                    }
                    guard builder.buildable else { return .none }
                    let chatTap = builder.build()
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

    class WeakStoreHolder {
        weak var store: StoreOf<GUI>?
    }

    private init() {
        let weakStoreHolder = WeakStoreHolder()
        let suggestionDependency = SuggestionWidgetControllerDependency()
        let setupDependency: (inout DependencyValues) -> Void = { dependencies in
            dependencies.suggestionWidgetControllerDependency = suggestionDependency
            dependencies.suggestionWidgetUserDefaultsObservers = .init()
            dependencies.chatTabBuilderCollection = {
                ChatTabFactory.chatTabBuilderCollection { tab in
                    weakStoreHolder.store?
                        .send(.suggestionWidget(.chatPanel(.appendAndSelectTab(tab))))
                }
            }
        }
        let store = StoreOf<GUI>(
            initialState: .init(),
            reducer: GUI(),
            prepareDependencies: setupDependency
        )
        weakStoreHolder.store = store
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

