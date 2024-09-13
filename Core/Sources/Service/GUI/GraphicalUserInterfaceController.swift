import ActiveApplicationMonitor
import AppActivator
import AppKit
import BuiltinExtension
import ChatGPTChatTab
import ChatTab
import ComposableArchitecture
import Dependencies
import Preferences
import SuggestionBasic
import SuggestionWidget

#if canImport(ProChatTabs)
import ProChatTabs
#endif

#if canImport(ChatTabPersistent)
import ChatTabPersistent
#endif

@Reducer
struct GUI {
    @ObservableState
    struct State {
        var suggestionWidgetState = Widget.State()

        var chatTabGroup: SuggestionWidget.ChatPanel.ChatTabGroup {
            get { suggestionWidgetState.chatPanelState.chatTabGroup }
            set { suggestionWidgetState.chatPanelState.chatTabGroup = newValue }
        }

        var promptToCodeGroup: PromptToCodeGroup.State {
            get { suggestionWidgetState.panelState.content.promptToCodeGroup }
            set { suggestionWidgetState.panelState.content.promptToCodeGroup = newValue }
        }

        #if canImport(ChatTabPersistent)
        var isChatTabRestoreFinished: Bool = false
        var persistentState: ChatTabPersistent.State {
            get {
                .init(
                    chatTabInfo: chatTabGroup.tabInfo,
                    isRestoreFinished: isChatTabRestoreFinished,
                    selectedChatTapId: chatTabGroup.selectedTabId
                )
            }
            set {
                chatTabGroup.tabInfo = newValue.chatTabInfo
                isChatTabRestoreFinished = newValue.isRestoreFinished
                chatTabGroup.selectedTabId = newValue.selectedChatTapId
            }
        }
        #endif
    }

    enum Action {
        case start
        case openChatPanel(forceDetach: Bool, activateThisApp: Bool)
        case createAndSwitchToChatGPTChatTabIfNeeded
        case createAndSwitchToChatTabIfNeededMatching(
            check: (any ChatTab) -> Bool,
            kind: ChatTabKind?
        )
        case sendCustomCommandToActiveChat(CustomCommand)
        case toggleWidgetsHotkeyPressed

        case suggestionWidget(Widget.Action)

        static func promptToCodeGroup(_ action: PromptToCodeGroup.Action) -> Self {
            .suggestionWidget(.panel(.sharedPanel(.promptToCodeGroup(action))))
        }

        #if canImport(ChatTabPersistent)
        case persistent(ChatTabPersistent.Action)
        #endif
    }

    @Dependency(\.chatTabPool) var chatTabPool
    @Dependency(\.activateThisApp) var activateThisApp

    public enum Debounce: Hashable {
        case updateChatTabOrder
    }

    var body: some ReducerOf<Self> {
        CombineReducers {
            Scope(state: \.suggestionWidgetState, action: \.suggestionWidget) {
                Widget()
            }

            Scope(
                state: \.chatTabGroup,
                action: \.suggestionWidget.chatPanel
            ) {
                Reduce { _, action in
                    switch action {
                    case let .createNewTapButtonClicked(kind):
                        return .run { send in
                            if let (_, chatTabInfo) = await chatTabPool.createTab(for: kind) {
                                await send(.appendAndSelectTab(chatTabInfo))
                            }
                        }

                    case let .closeTabButtonClicked(id):
                        return .run { _ in
                            chatTabPool.removeTab(of: id)
                        }

                    case let .chatTab(_, .openNewTab(builder)):
                        return .run { send in
                            if let (_, chatTabInfo) = await chatTabPool
                                .createTab(from: builder.chatTabBuilder)
                            {
                                await send(.appendAndSelectTab(chatTabInfo))
                            }
                        }

                    default:
                        return .none
                    }
                }
            }

            #if canImport(ChatTabPersistent)
            Scope(state: \.persistentState, action: \.persistent) {
                ChatTabPersistent()
            }
            #endif

            Reduce { state, action in
                switch action {
                case .start:
                    #if canImport(ChatTabPersistent)
                    return .run { send in
                        await send(.persistent(.restoreChatTabs))
                    }
                    #else
                    return .none
                    #endif

                case let .openChatPanel(forceDetach, activate):
                    return .run { send in
                        await send(
                            .suggestionWidget(
                                .chatPanel(.presentChatPanel(forceDetach: forceDetach))
                            )
                        )
                        await send(.suggestionWidget(.updateKeyWindow(.chatPanel)))

                        if activate {
                            activateThisApp()
                        }
                    }

                case .createAndSwitchToChatGPTChatTabIfNeeded:
                    return .run { send in
                        await send(.createAndSwitchToChatTabIfNeededMatching(
                            check: { $0 is ChatGPTChatTab },
                            kind: nil
                        ))
                    }

                case let .createAndSwitchToChatTabIfNeededMatching(check, kind):
                    if let selectedTabInfo = state.chatTabGroup.selectedTabInfo,
                       let tab = chatTabPool.getTab(of: selectedTabInfo.id),
                       check(tab)
                    {
                        // Already in ChatGPT tab
                        return .none
                    }

                    if let firstChatGPTTabInfo = state.chatTabGroup.tabInfo.first(where: {
                        if let tab = chatTabPool.getTab(of: $0.id) {
                            return check(tab)
                        }
                        return false
                    }) {
                        return .run { send in
                            await send(.suggestionWidget(.chatPanel(.tabClicked(
                                id: firstChatGPTTabInfo.id
                            ))))
                        }
                    }
                    return .run { send in
                        if let (_, chatTabInfo) = await chatTabPool.createTab(for: kind) {
                            await send(
                                .suggestionWidget(.chatPanel(.appendAndSelectTab(chatTabInfo)))
                            )
                        }
                    }
                    
                case let .sendCustomCommandToActiveChat(command):
                    @Sendable func stopAndHandleCommand(_ tab: ChatGPTChatTab) async {
                        if tab.service.isReceivingMessage {
                            await tab.service.stopReceivingMessage()
                        }
                        try? await tab.service.handleCustomCommand(command)
                    }

                    if let info = state.chatTabGroup.selectedTabInfo,
                       let activeTab = chatTabPool.getTab(of: info.id) as? ChatGPTChatTab
                    {
                        return .run { send in
                            await send(.openChatPanel(forceDetach: false, activateThisApp: false))
                            await stopAndHandleCommand(activeTab)
                        }
                    }

                    if let info = state.chatTabGroup.tabInfo.first(where: {
                        chatTabPool.getTab(of: $0.id) is ChatGPTChatTab
                    }),
                        let chatTab = chatTabPool.getTab(of: info.id) as? ChatGPTChatTab
                    {
                        state.chatTabGroup.selectedTabId = chatTab.id
                        return .run { send in
                            await send(.openChatPanel(forceDetach: false, activateThisApp: false))
                            await stopAndHandleCommand(chatTab)
                        }
                    }

                    return .run { send in
                        guard let (chatTab, chatTabInfo) = await chatTabPool.createTab(for: nil)
                        else { return }
                        await send(.suggestionWidget(.chatPanel(.appendAndSelectTab(chatTabInfo))))
                        await send(.openChatPanel(forceDetach: false, activateThisApp: false))
                        if let chatTab = chatTab as? ChatGPTChatTab {
                            await stopAndHandleCommand(chatTab)
                        }
                    }

                case .toggleWidgetsHotkeyPressed:
                    return .run { send in
                        await send(.suggestionWidget(.circularWidget(.widgetClicked)))
                    }

                case let .suggestionWidget(.chatPanel(.chatTab(id, .tabContentUpdated))):
                    #if canImport(ChatTabPersistent)
                    // when a tab is updated, persist it.
                    return .run { send in
                        await send(.persistent(.chatTabUpdated(id: id)))
                    }
                    #else
                    return .none
                    #endif

                case let .suggestionWidget(.chatPanel(.closeTabButtonClicked(id))):
                    #if canImport(ChatTabPersistent)
                    // when a tab is closed, remove it from persistence.
                    return .run { send in
                        await send(.persistent(.chatTabClosed(id: id)))
                    }
                    #else
                    return .none
                    #endif

                case .suggestionWidget:
                    return .none

                #if canImport(ChatTabPersistent)
                case .persistent:
                    return .none
                #endif
                }
            }
        }.onChange(of: \.chatTabGroup.tabInfo) { old, new in
            Reduce { _, _ in
                guard old.map(\.id) != new.map(\.id) else {
                    return .none
                }
                #if canImport(ChatTabPersistent)
                return .run { send in
                    await send(.persistent(.chatOrderChanged))
                }.debounce(id: Debounce.updateChatTabOrder, for: 1, scheduler: DispatchQueue.main)
                #else
                return .none
                #endif
            }
        }
    }
}

@MainActor
public final class GraphicalUserInterfaceController {
    let store: StoreOf<GUI>
    let widgetController: SuggestionWidgetController
    let widgetDataSource: WidgetDataSource
    let chatTabPool: ChatTabPool

    class WeakStoreHolder {
        weak var store: StoreOf<GUI>?
    }

    init() {
        let chatTabPool = ChatTabPool()
        let suggestionDependency = SuggestionWidgetControllerDependency()
        let setupDependency: (inout DependencyValues) -> Void = { dependencies in
            dependencies.suggestionWidgetControllerDependency = suggestionDependency
            dependencies.suggestionWidgetUserDefaultsObservers = .init()
            dependencies.chatTabPool = chatTabPool
            dependencies.chatTabBuilderCollection = ChatTabFactory.chatTabBuilderCollection
        
            #if canImport(ChatTabPersistent) && canImport(ProChatTabs)
            dependencies.restoreChatTabInPool = {
                await chatTabPool.restore($0)
            }
            #endif
        }
        let store = StoreOf<GUI>(
            initialState: .init(),
            reducer: { GUI() },
            withDependencies: setupDependency
        )
        self.store = store
        self.chatTabPool = chatTabPool
        widgetDataSource = .init()

        widgetController = SuggestionWidgetController(
            store: store.scope(
                state: \.suggestionWidgetState,
                action: \.suggestionWidget
            ),
            chatTabPool: chatTabPool,
            dependency: suggestionDependency
        )

        chatTabPool.createStore = { id in
            store.scope(
                state: { state in
                    state.chatTabGroup.tabInfo[id: id] ?? .init(id: id, title: "")
                },
                action: { childAction in
                    .suggestionWidget(.chatPanel(.chatTab(id: id, action: childAction)))
                }
            )
        }

        suggestionDependency.suggestionWidgetDataSource = widgetDataSource
        suggestionDependency.onOpenChatClicked = { [weak self] in
            Task { [weak self] in
                await self?.store.send(.createAndSwitchToChatGPTChatTabIfNeeded).finish()
                self?.store.send(.openChatPanel(forceDetach: false, activateThisApp: true))
            }
        }
        suggestionDependency.onCustomCommandClicked = { command in
            Task {
                let commandHandler = PseudoCommandHandler()
                await commandHandler.handleCustomCommand(command)
            }
        }
    }

    func start() {
        store.send(.start)
    }

    public func openGlobalChat() {
        PseudoCommandHandler().openChat(forceDetach: true)
    }
}

extension ChatTabPool {
    @MainActor
    func createTab(
        id: String = UUID().uuidString,
        from builder: ChatTabBuilder
    ) async -> (any ChatTab, ChatTabInfo)? {
        let id = id
        let info = ChatTabInfo(id: id, title: "")
        guard let chatTap = await builder.build(store: createStore(id)) else { return nil }
        setTab(chatTap)
        return (chatTap, info)
    }

    @MainActor
    func createTab(
        for kind: ChatTabKind?
    ) async -> (any ChatTab, ChatTabInfo)? {
        let id = UUID().uuidString
        let info = ChatTabInfo(id: id, title: "")
        let builder = kind?.builder ?? ChatGPTChatTab.defaultBuilder()
        guard let chatTap = await builder.build(store: createStore(id)) else { return nil }
        setTab(chatTap)
        return (chatTap, info)
    }

    #if canImport(ChatTabPersistent) && canImport(ProChatTabs)
    @MainActor
    func restore(
        _ data: ChatTabPersistent.RestorableTabData
    ) async -> (any ChatTab, ChatTabInfo)? {
        switch data.name {
        case ChatGPTChatTab.name:
            guard let builder = try? await ChatGPTChatTab.restore(from: data.data) else { break }
            return await createTab(id: data.id, from: builder)
        case BrowserChatTab.name:
            guard let builder = try? BrowserChatTab.restore(from: data.data) else { break }
            return await createTab(id: data.id, from: builder)
        case TerminalChatTab.name:
            guard let builder = try? await TerminalChatTab.restore(from: data.data) else { break }
            return await createTab(id: data.id, from: builder)
        default:
            let chatTabTypes = BuiltinExtensionManager.shared.extensions.flatMap(\.chatTabTypes)
            for type in chatTabTypes {
                if type.name == data.name {
                    guard let builder = try? await type.restore(from: data.data) else { break }
                    return await createTab(id: data.id, from: builder)
                }
            }
        }

        guard let builder = try? await EmptyChatTab.restore(from: data.data) else { return nil }
        return await createTab(id: data.id, from: builder)
    }
    #endif
}

