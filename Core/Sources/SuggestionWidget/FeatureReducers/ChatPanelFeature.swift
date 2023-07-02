import ActiveApplicationMonitor
import AppKit
import ChatTab
import ComposableArchitecture
import SwiftUI

extension ChatProvider: Equatable {
    public static func == (lhs: ChatProvider, rhs: ChatProvider) -> Bool {
        lhs.id == rhs.id
    }
}

struct ChatPanelFeature: ReducerProtocol {
    struct State: Equatable {
        var chat: ChatProvider?
        var colorScheme: ColorScheme = .light
        var isPanelDisplayed = false
        var chatPanelInASeparateWindow = false
    }

    enum Action: Equatable {
        case hideButtonClicked
        case toggleChatPanelDetachedButtonClicked
        case detachChatPanel
        case attachChatPanel
        case presentChatPanel(forceDetach: Bool)
        case closeChatPanel

        case updateContent
        case updateChatProvider(ChatProvider?)
    }

    @Dependency(\.suggestionWidgetControllerDependency) var suggestionWidgetControllerDependency
    @Dependency(\.xcodeInspector) var xcodeInspector
    @Dependency(\.activeApplicationMonitor) var activeApplicationMonitor

    var body: some ReducerProtocol<State, Action> {
        Reduce { state, action in
            switch action {
            case .hideButtonClicked:
                state.isPanelDisplayed = false
                if let app = activeApplicationMonitor.previousActiveApplication, app.isXcode {
                    app.activate()
                }
                return .none

            case .toggleChatPanelDetachedButtonClicked:
                state.chatPanelInASeparateWindow.toggle()
                return .none

            case .detachChatPanel:
                state.chatPanelInASeparateWindow = true
                return .none

            case .attachChatPanel:
                state.chatPanelInASeparateWindow = false
                return .none
                
            case .closeChatPanel:
                state.chat = nil
                return .none

            case let .presentChatPanel(forceDetach):
                if forceDetach {
                    state.chatPanelInASeparateWindow = true
                }
                let oldChatProviderId = state.chat?.id
                return .run { send in
                    guard let provider = await fetchChatProvider(
                        fileURL: xcodeInspector.activeDocumentURL
                    ) else { return }
                    
                    if oldChatProviderId != provider.id {
                        await send(.updateChatProvider(provider))
                    }

                    try await Task.sleep(nanoseconds: 150_000_000)
                    await NSApplication.shared.activate(ignoringOtherApps: true)
                }

            case .updateContent:
                let oldChatProviderId = state.chat?.id
                return .run { send in
                    if let provider = await fetchChatProvider(
                        fileURL: xcodeInspector.activeDocumentURL
                    ) {
                        if oldChatProviderId != provider.id {
                            await send(.updateChatProvider(provider))
                        }
                    } else {
                        await send(.updateChatProvider(nil))
                    }
                }

            case let .updateChatProvider(provider):
                state.chat = provider
                state.isPanelDisplayed = provider != nil
                return .none
            }
        }
    }

    func fetchChatProvider(fileURL: URL) async -> ChatProvider? {
        await suggestionWidgetControllerDependency
            .suggestionWidgetDataSource?
            .chatForFile(at: fileURL)
    }
}
