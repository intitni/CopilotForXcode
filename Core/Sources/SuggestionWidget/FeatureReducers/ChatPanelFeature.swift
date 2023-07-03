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
        case updateChatProvider(ChatProvider?, forceDisplayIfPossible: Bool)
    }

    @Dependency(\.suggestionWidgetControllerDependency) var suggestionWidgetControllerDependency
    @Dependency(\.xcodeInspector) var xcodeInspector
    @Dependency(\.activeApplicationMonitor) var activeApplicationMonitor

    var body: some ReducerProtocol<State, Action> {
        Reduce { state, action in
            switch action {
            case .hideButtonClicked:
                state.isPanelDisplayed = false

                return .run { _ in
                    if let app = activeApplicationMonitor.previousActiveApplication, app.isXcode {
                        try await Task.sleep(nanoseconds: 200_000_000)
                        app.activate()
                    }
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

            case .closeChatPanel:
                state.chat = nil
                return .none

            case let .presentChatPanel(forceDetach):
                if forceDetach {
                    state.chatPanelInASeparateWindow = true
                }

                return .run { send in
                    guard let provider = await fetchChatProvider(
                        fileURL: xcodeInspector.activeDocumentURL
                    ) else { return }
                    await send(.updateChatProvider(provider, forceDisplayIfPossible: true))

                    try await Task.sleep(nanoseconds: 150_000_000)
                    await NSApplication.shared.activate(ignoringOtherApps: true)
                }

            case .updateContent:
                return .run { send in
                    if let provider = await fetchChatProvider(
                        fileURL: xcodeInspector.activeDocumentURL
                    ) {
                        await send(.updateChatProvider(provider, forceDisplayIfPossible: false))
                    } else {
                        await send(.updateChatProvider(nil, forceDisplayIfPossible: true))
                    }
                }

            case let .updateChatProvider(provider, updateDisplay):
                if state.chat?.id != provider?.id {
                    state.chat = provider
                }
                if updateDisplay {
                    state.isPanelDisplayed = provider != nil
                }
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

