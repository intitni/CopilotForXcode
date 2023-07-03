import ActiveApplicationMonitor
import AppKit
import ChatTab
import ComposableArchitecture
import SwiftUI

struct ChatPanelFeature: ReducerProtocol {
    struct State: Equatable {
        var chatTabs: [BaseChatTab] = []
        var colorScheme: ColorScheme = .light
        var isPanelDisplayed = false
        var chatPanelInASeparateWindow = false
        var tabIndex = 0

        var currentTab: BaseChatTab? {
            if tabIndex >= 0, tabIndex < chatTabs.endIndex {
                return chatTabs[tabIndex]
            } else {
                return nil
            }
        }
    }

    enum Action: Equatable {
        case hideButtonClicked
        case toggleChatPanelDetachedButtonClicked
        case detachChatPanel
        case attachChatPanel
        case presentChatPanel(forceDetach: Bool)

        case updateContent
        case updateChatTabs([BaseChatTab])
        case closeTabButtonClicked(index: Int)
        case createNewTapButtonClicked
        case tabClicked(index: Int)
    }

    @Dependency(\.suggestionWidgetControllerDependency) var suggestionWidgetControllerDependency
    @Dependency(\.xcodeInspector) var xcodeInspector
    @Dependency(\.activatePreviouslyActiveXcode) var activatePreviouslyActiveXcode
    @Dependency(\.activateExtensionService) var activateExtensionService

    var body: some ReducerProtocol<State, Action> {
        Reduce { state, action in
            switch action {
            case .hideButtonClicked:
                state.isPanelDisplayed = false

                return .run { _ in
                    await activatePreviouslyActiveXcode()
                }

            case .toggleChatPanelDetachedButtonClicked:
                state.chatPanelInASeparateWindow.toggle()
                return .none

            case .detachChatPanel:
                state.chatPanelInASeparateWindow = true
                return .none

            case .attachChatPanel:
                state.chatPanelInASeparateWindow = false
                return .none

            case let .presentChatPanel(forceDetach):
                if forceDetach {
                    state.chatPanelInASeparateWindow = true
                }
                return .run { send in
                    let tabs = await fetchChatTabs()
                    await send(.updateChatTabs(tabs))
                    await activateExtensionService()
                }

            case .updateContent:
                return .run { send in
                    let tabs = await fetchChatTabs()
                    await send(.updateChatTabs(tabs))
                }

            case let .updateChatTabs(tabs):
                state.chatTabs = tabs
                state.isPanelDisplayed = !tabs.isEmpty
                return .none

            case let .closeTabButtonClicked(index):
                return .none
                
            case .createNewTapButtonClicked:
                return .none
                
            case let .tabClicked(index):
                return .none
            }
        }
    }

    func fetchChatTabs() async -> [ChatTab] {
        return []
//        await suggestionWidgetControllerDependency
//            .suggestionWidgetDataSource?
//            .chatForFile(at: fileURL)
    }
}

