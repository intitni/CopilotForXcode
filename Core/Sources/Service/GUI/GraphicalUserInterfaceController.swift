import ActiveApplicationMonitor
import AppActivator
import AppKit
import BuiltinExtension
import ChatGPTChatTab
import ChatTab
import ComposableArchitecture
import Dependencies
import Logger
import Preferences
import SuggestionBasic
import SuggestionWidget

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

                    case let .chatTab(.element(_, .openNewTab(builder))):
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
                    if let info = state.chatTabGroup.selectedTabInfo,
                       let tab = chatTabPool.getTab(of: info.id),
                       tab.handleCustomCommand(command)
                    {
                        return .run { send in
                            await send(.openChatPanel(forceDetach: false, activateThisApp: false))
                        }
                    }

                    for info in state.chatTabGroup.tabInfo {
                        if let chatTab = chatTabPool.getTab(of: info.id),
                           chatTab.handleCustomCommand(command)
                        {
                            state.chatTabGroup.selectedTabId = chatTab.id
                            return .run { send in
                                await send(.openChatPanel(
                                    forceDetach: false,
                                    activateThisApp: false
                                ))
                            }
                        }
                    }

                    return .run { send in
                        guard let (chatTab, chatTabInfo) = await chatTabPool.createTab(for: nil)
                        else { return }
                        await send(.suggestionWidget(.chatPanel(.appendAndSelectTab(chatTabInfo))))
                        await send(.openChatPanel(forceDetach: false, activateThisApp: false))
                        _ = chatTab.handleCustomCommand(command)
                    }

                case .toggleWidgetsHotkeyPressed:
                    return .run { send in
                        await send(.suggestionWidget(.circularWidget(.widgetClicked)))
                    }

                case let .suggestionWidget(.chatPanel(.chatTab(.element(id, .tabContentUpdated)))):
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

        widgetController = SuggestionWidgetController(
            store: store.scope(
                state: \.suggestionWidgetState,
                action: \.suggestionWidget
            ),
            chatTabPool: chatTabPool,
            dependency: suggestionDependency
        )

        chatTabPool.createStore = { id in
            return store.scope(
                state: \.chatTabGroup[chatTab: id],
                action: \.suggestionWidget.chatPanel.chatTab[id: id]
            )
        }

        suggestionDependency.onOpenChatClicked = { [weak self] in
            Task {
                PseudoCommandHandler().openChat(forceDetach: false, activateThisApp: true)
            }
        }
        suggestionDependency.onOpenModificationButtonClicked = {
            Task {
                guard let content = await PseudoCommandHandler().getEditorContent(sourceEditor: nil)
                else { return }
                _ = try await WindowBaseCommandHandler().promptToCode(editor: content)
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
        setTab(chatTap, forId: id)
        return (chatTap, info)
    }

    @MainActor
    func createTab(
        for kind: ChatTabKind?
    ) async -> (any ChatTab, ChatTabInfo)? {
        let id = UUID().uuidString
        let info = ChatTabInfo(id: id, title: "")
        let builder = kind?.builder ?? {
            for ext in BuiltinExtensionManager.shared.extensions {
                guard let tab = ext.chatTabTypes.first(where: { $0.isDefaultChatTabReplacement })
                else { continue }
                return tab.defaultChatBuilder()
            }
            return ChatGPTChatTab.defaultBuilder()
        }()
        guard let chatTap = await builder.build(store: createStore(id)) else { return nil }
        setTab(chatTap, forId: id)
        return (chatTap, info)
    }

    #if canImport(ChatTabPersistent)
    @MainActor
    func restore(
        _ data: ChatTabPersistent.RestorableTabData
    ) async -> (any ChatTab, ChatTabInfo)? {
        switch data.name {
        case ChatGPTChatTab.name:
            guard let builder = try? await ChatGPTChatTab.restore(from: data.data)
            else { fallthrough }
            return await createTab(id: data.id, from: builder)
        default:
            let chatTabTypes = BuiltinExtensionManager.shared.extensions.flatMap(\.chatTabTypes)
            for type in chatTabTypes {
                if type.name == data.name {
                    do {
                        let builder = try await type.restore(from: data.data)
                        return await createTab(id: data.id, from: builder)
                    } catch {
                        Logger.service.error("Failed to restore chat tab \(data.name): \(error)")
                        break
                    }
                }
            }
        }

        guard let builder = try? await EmptyChatTab.restore(from: data.data) else { return nil }
        return await createTab(id: data.id, from: builder)
    }
    #endif
}

