import ActiveApplicationMonitor
import AppActivator
import AsyncAlgorithms
import ComposableArchitecture
import Foundation
import Logger
import Preferences
import SwiftUI
import Toast
import XcodeInspector

public struct WidgetFeature: ReducerProtocol {
    public struct WindowState: Equatable {
        var alphaValue: Double = 0
        var frame: CGRect = .zero
    }

    public enum WindowCanBecomeKey: Equatable {
        case sharedPanel
        case chatPanel
    }

    public struct State: Equatable {
        var focusingDocumentURL: URL?
        public var colorScheme: ColorScheme = .light

        var toastPanel = ToastPanel.State()

        // MARK: Panels

        public var panelState = PanelFeature.State()

        // MARK: ChatPanel

        public var chatPanelState = ChatPanelFeature.State()

        // MARK: CircularWidget

        public struct CircularWidgetState: Equatable {
            var isProcessingCounters = [CircularWidgetFeature.IsProcessingCounter]()
            var isProcessing: Bool = false
        }

        public var circularWidgetState = CircularWidgetState()
        var _circularWidgetState: CircularWidgetFeature.State {
            get {
                .init(
                    isProcessingCounters: circularWidgetState.isProcessingCounters,
                    isProcessing: circularWidgetState.isProcessing,
                    isDisplayingContent: {
                        if chatPanelState.isPanelDisplayed {
                            return true
                        }
                        if panelState.sharedPanelState.isPanelDisplayed,
                           !panelState.sharedPanelState.isEmpty
                        {
                            return true
                        }
                        if panelState.suggestionPanelState.isPanelDisplayed,
                           panelState.suggestionPanelState.content != nil
                        {
                            return true
                        }
                        return false
                    }(),
                    isContentEmpty: chatPanelState.chatTabGroup.tabInfo.isEmpty
                        && panelState.sharedPanelState.isEmpty,
                    isChatPanelDetached: chatPanelState.chatPanelInASeparateWindow,
                    isChatOpen: chatPanelState.isPanelDisplayed
                )
            }
            set {
                circularWidgetState = .init(
                    isProcessingCounters: newValue.isProcessingCounters,
                    isProcessing: newValue.isProcessing
                )
            }
        }

        public init() {}
    }

    private enum CancelID {
        case observeActiveApplicationChange
        case observeCompletionPanelChange
        case observeFullscreenChange
        case observeWindowChange
        case observeEditorChange
        case observeUserDefaults
    }

    public enum Action: Equatable {
        case startup
        case observeActiveApplicationChange
        case observeFullscreenChange
        case observeColorSchemeChange

        case updateActiveApplication
        case updateColorScheme

        case updatePanelStateToMatch(WidgetLocation)
        case updateFocusingDocumentURL
        case updateKeyWindow(WindowCanBecomeKey)

        case toastPanel(ToastPanel.Action)
        case panel(PanelFeature.Action)
        case chatPanel(ChatPanelFeature.Action)
        case circularWidget(CircularWidgetFeature.Action)
    }

    var windowsController: WidgetWindowsController? {
        suggestionWidgetControllerDependency.windowsController
    }

    @Dependency(\.suggestionWidgetUserDefaultsObservers) var userDefaultsObservers
    @Dependency(\.suggestionWidgetControllerDependency) var suggestionWidgetControllerDependency
    @Dependency(\.xcodeInspector) var xcodeInspector
    @Dependency(\.mainQueue) var mainQueue
    @Dependency(\.activateThisApp) var activateThisApp
    @Dependency(\.activatePreviousActiveApp) var activatePreviousActiveApp

    public enum DebounceKey: Hashable {
        case updateWindowOpacity
    }

    public init() {}

    public var body: some ReducerProtocol<State, Action> {
        Scope(state: \.toastPanel, action: /Action.toastPanel) {
            ToastPanel()
        }

        Scope(state: \._circularWidgetState, action: /Action.circularWidget) {
            CircularWidgetFeature()
        }

        Reduce { state, action in
            switch action {
            case .circularWidget(.detachChatPanelToggleClicked):
                return .run { send in
                    await send(.chatPanel(.toggleChatPanelDetachedButtonClicked))
                }

            case .circularWidget(.widgetClicked):
                let wasDisplayingContent = state._circularWidgetState.isDisplayingContent
                if wasDisplayingContent {
                    state.panelState.sharedPanelState.isPanelDisplayed = false
                    state.panelState.suggestionPanelState.isPanelDisplayed = false
                    state.chatPanelState.isPanelDisplayed = false
                } else {
                    state.panelState.sharedPanelState.isPanelDisplayed = true
                    state.panelState.suggestionPanelState.isPanelDisplayed = true
                    state.chatPanelState.isPanelDisplayed = true
                }

                let isDisplayingContent = state._circularWidgetState.isDisplayingContent
                let hasChat = state.chatPanelState.chatTabGroup.selectedTabInfo != nil
                let hasPromptToCode = state.panelState.sharedPanelState.content
                    .promptToCodeGroup.activePromptToCode != nil

                return .run { send in
                    if isDisplayingContent {
                        if hasPromptToCode {
                            await send(.updateKeyWindow(.sharedPanel))
                        } else if hasChat {
                            await send(.updateKeyWindow(.chatPanel))
                        }
                        await send(.chatPanel(.focusActiveChatTab))
                    }

                    if isDisplayingContent, !(await NSApplication.shared.isActive) {
                        activateThisApp()
                    } else if !isDisplayingContent {
                        activatePreviousActiveApp()
                    }
                }

            default: return .none
            }
        }

        Scope(state: \.panelState, action: /Action.panel) {
            PanelFeature()
        }

        Scope(state: \.chatPanelState, action: /Action.chatPanel) {
            ChatPanelFeature()
        }

        Reduce { state, action in
            switch action {
            case .chatPanel(.presentChatPanel):
                let isDetached = state.chatPanelState.chatPanelInASeparateWindow
                return .run { _ in
                    await windowsController?.updateWindowLocation(
                        animated: false,
                        immediately: false
                    )
                    await windowsController?.updateWindowOpacity(immediately: false)
                    if isDetached {
                        Task { @MainActor in
                            windowsController?.windows.chatPanelWindow.isWindowHidden = false
                        }
                    }
                }

            case .chatPanel(.toggleChatPanelDetachedButtonClicked):
                let isDetached = state.chatPanelState.chatPanelInASeparateWindow
                return .run { _ in
                    await windowsController?.updateWindowLocation(
                        animated: !isDetached,
                        immediately: false
                    )
                    await windowsController?.updateWindowOpacity(immediately: false)
                }
            default: return .none
            }
        }

        Reduce { state, action in
            switch action {
            case .startup:
                return .merge(
                    .run { send in
                        await send(.toastPanel(.start))
                        await send(.observeActiveApplicationChange)
                        await send(.observeFullscreenChange)
                        await send(.observeColorSchemeChange)
                    }
                )

            case .observeActiveApplicationChange:
                return .run { send in
                    let stream = AsyncStream<AppInstanceInspector> { continuation in
                        let cancellable = xcodeInspector.$activeApplication.sink { newValue in
                            guard let newValue else { return }
                            continuation.yield(newValue)
                        }
                        continuation.onTermination = { _ in
                            cancellable.cancel()
                        }
                    }

                    var previousAppIdentifier: pid_t?
                    for await app in stream {
                        try Task.checkCancellation()
                        if app.processIdentifier != previousAppIdentifier {
                            await send(.updateActiveApplication)
                        }
                        previousAppIdentifier = app.processIdentifier
                    }
                }.cancellable(id: CancelID.observeActiveApplicationChange, cancelInFlight: true)

            case .observeFullscreenChange:
                return .run { _ in
                    let sequence = NSWorkspace.shared.notificationCenter
                        .notifications(named: NSWorkspace.activeSpaceDidChangeNotification)
                    for await _ in sequence {
                        try Task.checkCancellation()
                        guard let activeXcode = xcodeInspector.activeXcode else { continue }
                        guard let windowsController,
                              await windowsController.windows.fullscreenDetector.isOnActiveSpace
                        else { continue }
                        let app = AXUIElementCreateApplication(
                            activeXcode.processIdentifier
                        )
                        if let _ = app.focusedWindow {
                            await windowsController.windows.orderFront()
                        }
                    }
                }.cancellable(id: CancelID.observeFullscreenChange, cancelInFlight: true)

            case .observeColorSchemeChange:
                return .run { send in
                    await send(.updateColorScheme)
                    let stream = AsyncStream<Void> { continuation in
                        userDefaultsObservers.colorSchemeChangeObserver.onChange = {
                            continuation.yield()
                        }

                        userDefaultsObservers.systemColorSchemeChangeObserver.onChange = {
                            continuation.yield()
                        }

                        continuation.onTermination = { _ in
                            userDefaultsObservers.colorSchemeChangeObserver.onChange = {}
                            userDefaultsObservers.systemColorSchemeChangeObserver.onChange = {}
                        }
                    }

                    for await _ in stream {
                        try Task.checkCancellation()
                        await send(.updateColorScheme)
                    }
                }.cancellable(id: CancelID.observeUserDefaults, cancelInFlight: true)

            case .updateActiveApplication:
                if let app = xcodeInspector.activeApplication, app.isXcode {
                    return .run { send in
                        await send(.panel(.switchToAnotherEditorAndUpdateContent))
                    }
                }
                return .none

            case .updateColorScheme:
                let widgetColorScheme = UserDefaults.shared.value(for: \.widgetColorScheme)
                let systemColorScheme: ColorScheme = NSApp.effectiveAppearance.name == .darkAqua
                    ? .dark
                    : .light

                let scheme: ColorScheme = {
                    switch (widgetColorScheme, systemColorScheme) {
                    case (.system, .dark), (.dark, _):
                        return .dark
                    case (.system, .light), (.light, _):
                        return .light
                    case (.system, _):
                        return .light
                    }
                }()

                state.colorScheme = scheme
                state.toastPanel.colorScheme = scheme
                state.panelState.sharedPanelState.colorScheme = scheme
                state.panelState.suggestionPanelState.colorScheme = scheme
                state.chatPanelState.colorScheme = scheme
                return .none

            case .updateFocusingDocumentURL:
                state.focusingDocumentURL = xcodeInspector.realtimeActiveDocumentURL
                return .none

            case let .updatePanelStateToMatch(widgetLocation):
                state.panelState.sharedPanelState.alignTopToAnchor = widgetLocation
                    .defaultPanelLocation
                    .alignPanelTop

                if let suggestionPanelLocation = widgetLocation.suggestionPanelLocation {
                    state.panelState.suggestionPanelState.isPanelOutOfFrame = false
                    state.panelState.suggestionPanelState
                        .alignTopToAnchor = suggestionPanelLocation
                        .alignPanelTop
                } else {
                    state.panelState.suggestionPanelState.isPanelOutOfFrame = true
                }

                state.toastPanel.alignTopToAnchor = widgetLocation
                    .defaultPanelLocation
                    .alignPanelTop

                return .none

            case let .updateKeyWindow(window):
                return .run { _ in
                    await MainActor.run {
                        switch window {
                        case .chatPanel:
                            windowsController?.windows.chatPanelWindow
                                .makeKeyAndOrderFront(nil)
                        case .sharedPanel:
                            windowsController?.windows.sharedPanelWindow
                                .makeKeyAndOrderFront(nil)
                        }
                    }
                }

            case .toastPanel:
                return .none

            case .circularWidget:
                return .none

            case .panel:
                return .none

            case .chatPanel:
                return .none
            }
        }
    }
}

