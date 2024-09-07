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

@Reducer
public struct Widget {
    public struct WindowState: Equatable {
        var alphaValue: Double = 0
        var frame: CGRect = .zero
    }

    public enum WindowCanBecomeKey: Equatable {
        case sharedPanel
        case chatPanel
    }

    @ObservableState
    public struct State {
        var focusingDocumentURL: URL?
        public var colorScheme: ColorScheme = .light

        var toastPanel = ToastPanel.State()

        // MARK: Panels

        public var panelState = WidgetPanel.State()

        // MARK: ChatPanel

        public var chatPanelState = ChatPanel.State()

        // MARK: CircularWidget

        public struct CircularWidgetState: Equatable {
            var isProcessingCounters = [CircularWidget.IsProcessingCounter]()
            var isProcessing: Bool = false
        }

        public var circularWidgetState = CircularWidgetState()
        var _internalCircularWidgetState: CircularWidget.State {
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
                    isChatPanelDetached: chatPanelState.isDetached,
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
        case observeWindowChange
        case observeEditorChange
        case observeUserDefaults
    }

    public enum Action {
        case startup
        case observeActiveApplicationChange
        case observeColorSchemeChange

        case updateActiveApplication
        case updateColorScheme

        case updatePanelStateToMatch(WidgetLocation)
        case updateFocusingDocumentURL
        case setFocusingDocumentURL(to: URL?)
        case updateKeyWindow(WindowCanBecomeKey)

        case toastPanel(ToastPanel.Action)
        case panel(WidgetPanel.Action)
        case chatPanel(ChatPanel.Action)
        case circularWidget(CircularWidget.Action)
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

    public var body: some ReducerOf<Self> {
        Scope(state: \.toastPanel, action: \.toastPanel) {
            ToastPanel()
        }

        Scope(state: \._internalCircularWidgetState, action: \.circularWidget) {
            CircularWidget()
        }

        Reduce { state, action in
            switch action {
            case .circularWidget(.detachChatPanelToggleClicked):
                return .run { send in
                    await send(.chatPanel(.toggleChatPanelDetachedButtonClicked))
                }

            case .circularWidget(.widgetClicked):
                let wasDisplayingContent = state._internalCircularWidgetState.isDisplayingContent
                if wasDisplayingContent {
                    state.panelState.sharedPanelState.isPanelDisplayed = false
                    state.panelState.suggestionPanelState.isPanelDisplayed = false
                    state.chatPanelState.isPanelDisplayed = false
                } else {
                    state.panelState.sharedPanelState.isPanelDisplayed = true
                    state.panelState.suggestionPanelState.isPanelDisplayed = true
                    state.chatPanelState.isPanelDisplayed = true
                }

                let isDisplayingContent = state._internalCircularWidgetState.isDisplayingContent
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

        Scope(state: \.panelState, action: \.panel) {
            WidgetPanel()
        }

        Scope(state: \.chatPanelState, action: \.chatPanel) {
            ChatPanel()
        }

        Reduce { state, action in
            switch action {
            case .chatPanel(.presentChatPanel):
                let isDetached = state.chatPanelState.isDetached
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
                let isDetached = state.chatPanelState.isDetached
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
                return .run { send in
                    await send(.setFocusingDocumentURL(
                        to: await xcodeInspector.safe
                            .realtimeActiveDocumentURL
                    ))
                }

            case let .setFocusingDocumentURL(url):
                state.focusingDocumentURL = url
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

