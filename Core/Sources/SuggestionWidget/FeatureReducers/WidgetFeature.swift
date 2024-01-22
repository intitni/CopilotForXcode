import ActiveApplicationMonitor
import AppActivator
import AsyncAlgorithms
import AXNotificationStream
import ComposableArchitecture
import Foundation
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
            var animationProgress: Double = 0
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
                    isChatOpen: chatPanelState.isPanelDisplayed,
                    animationProgress: circularWidgetState.animationProgress
                )
            }
            set {
                circularWidgetState = .init(
                    isProcessingCounters: newValue.isProcessingCounters,
                    isProcessing: newValue.isProcessing,
                    animationProgress: newValue.animationProgress
                )
            }
        }

        var lastUpdateWindowOpacityTime = Date(timeIntervalSince1970: 0)

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
        case observeCompletionPanelChange
        case observeFullscreenChange
        case observeColorSchemeChange
        case observePresentationModeChange

        case observeWindowChange
        case observeEditorChange

        case updateActiveApplication
        case updateColorScheme

        case updateWindowLocation(animated: Bool)
        case updateWindowOpacity(immediately: Bool)
        case updateFocusingDocumentURL
        case updateWindowOpacityFinished
        case updateKeyWindow(WindowCanBecomeKey)

        case toastPanel(ToastPanel.Action)
        case panel(PanelFeature.Action)
        case chatPanel(ChatPanelFeature.Action)
        case circularWidget(CircularWidgetFeature.Action)
    }

    var windows: WidgetWindows {
        suggestionWidgetControllerDependency.windows
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
                return .run { send in
                    await send(.updateWindowLocation(animated: false))
                    await send(.updateWindowOpacity(immediately: false))
                    if isDetached {
                        Task { @MainActor in
                            windows.chatPanelWindow.alphaValue = 1
                        }
                    }
                }
            case .chatPanel(.toggleChatPanelDetachedButtonClicked):
                let isDetached = state.chatPanelState.chatPanelInASeparateWindow
                return .run { send in
                    await send(.updateWindowLocation(animated: !isDetached))
                    await send(.updateWindowOpacity(immediately: false))
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
                        await send(.observeCompletionPanelChange)
                        await send(.observeFullscreenChange)
                        await send(.observeColorSchemeChange)
                        await send(.observePresentationModeChange)
                    }
                )

            case .observeActiveApplicationChange:
                return .run { send in
                    let stream = AsyncStream<NSRunningApplication> { continuation in
                        let cancellable = xcodeInspector.$activeApplication.sink { newValue in
                            guard let newValue else { return }
                            continuation.yield(newValue.runningApplication)
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

            case .observeCompletionPanelChange:
                return .run { send in
                    let stream = AsyncStream<Void> { continuation in
                        let cancellable = XcodeInspector.shared.$completionPanel.sink { newValue in
                            Task {
                                if newValue == nil {
                                    // so that the buttons on the suggestion panel could be
                                    // clicked
                                    // before the completion panel updates the location of the
                                    // suggestion panel
                                    try await Task.sleep(nanoseconds: 400_000_000)
                                }
                                continuation.yield()
                            }
                        }
                        continuation.onTermination = { _ in
                            cancellable.cancel()
                        }
                    }
                    for await _ in stream {
                        try Task.checkCancellation()
                        await send(.updateWindowLocation(animated: false))
                        await send(.updateWindowOpacity(immediately: false))
                    }
                }.cancellable(id: CancelID.observeCompletionPanelChange, cancelInFlight: true)

            case .observeFullscreenChange:
                return .run { _ in
                    let sequence = NSWorkspace.shared.notificationCenter
                        .notifications(named: NSWorkspace.activeSpaceDidChangeNotification)
                    for await _ in sequence {
                        try Task.checkCancellation()
                        guard let activeXcode = xcodeInspector.activeXcode else { continue }
                        guard await windows.fullscreenDetector.isOnActiveSpace else { continue }
                        let app = AXUIElementCreateApplication(
                            activeXcode.runningApplication.processIdentifier
                        )
                        if let _ = app.focusedWindow {
                            await windows.orderFront()
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

            case .observePresentationModeChange:
                return .run { send in
                    await send(.updateColorScheme)
                    let stream = AsyncStream<Void> { continuation in
                        userDefaultsObservers.presentationModeChangeObserver.onChange = {
                            continuation.yield()
                        }

                        continuation.onTermination = { _ in
                            userDefaultsObservers.presentationModeChangeObserver.onChange = {}
                        }
                    }

                    for await _ in stream {
                        try Task.checkCancellation()
                        await send(.updateWindowLocation(animated: false))
                    }
                }.cancellable(id: CancelID.observeUserDefaults, cancelInFlight: true)

            case .observeWindowChange:
                guard let app = xcodeInspector.activeApplication else { return .none }
                guard app.isXcode else { return .none }

                let documentURL = state.focusingDocumentURL

                let notifications = AXNotificationStream(
                    app: app.runningApplication,
                    notificationNames:
                    kAXApplicationActivatedNotification,
                    kAXMovedNotification,
                    kAXResizedNotification,
                    kAXMainWindowChangedNotification,
                    kAXFocusedWindowChangedNotification,
                    kAXFocusedUIElementChangedNotification,
                    kAXWindowMovedNotification,
                    kAXWindowResizedNotification,
                    kAXWindowMiniaturizedNotification,
                    kAXWindowDeminiaturizedNotification
                )

                return .run { send in
                    await send(.observeEditorChange)
                    await send(.panel(.switchToAnotherEditorAndUpdateContent))

                    for await notification in notifications {
                        try Task.checkCancellation()

                        // Hide the widgets before switching to another window/editor
                        // so the transition looks better.
                        if [
                            kAXFocusedUIElementChangedNotification,
                            kAXFocusedWindowChangedNotification,
                        ].contains(notification.name) {
                            let newDocumentURL = xcodeInspector.realtimeActiveDocumentURL
                            if documentURL != newDocumentURL {
                                await send(.panel(.removeDisplayedContent))
                                await hidePanelWindows()
                            }
                            await send(.updateFocusingDocumentURL)
                        }

                        // update widgets.
                        if [
                            kAXFocusedUIElementChangedNotification,
                            kAXApplicationActivatedNotification,
                            kAXMainWindowChangedNotification,
                            kAXFocusedWindowChangedNotification,
                        ].contains(notification.name) {
                            await send(.updateWindowLocation(animated: false))
                            await send(.updateWindowOpacity(immediately: false))
                            await send(.observeEditorChange)
                            await send(.panel(.switchToAnotherEditorAndUpdateContent))
                        } else {
                            await send(.updateWindowLocation(animated: false))
                            await send(.updateWindowOpacity(immediately: false))
                        }
                    }
                }.cancellable(id: CancelID.observeWindowChange, cancelInFlight: true)

            case .observeEditorChange:
                guard let app = xcodeInspector.activeApplication else { return .none }
                let appElement = AXUIElementCreateApplication(
                    app.runningApplication.processIdentifier
                )
                guard let focusedElement = appElement.focusedElement,
                      focusedElement.description == "Source Editor",
                      let scrollView = focusedElement.parent,
                      let scrollBar = scrollView.verticalScrollBar
                else { return .none }

                let selectionRangeChange = AXNotificationStream(
                    app: app.runningApplication,
                    element: focusedElement,
                    notificationNames: kAXSelectedTextChangedNotification
                )
                let scroll = AXNotificationStream(
                    app: app.runningApplication,
                    element: scrollBar,
                    notificationNames: kAXValueChangedNotification
                )

                return .run { send in
                    if #available(macOS 13.0, *) {
                        for await _ in merge(
                            selectionRangeChange.debounce(for: Duration.milliseconds(500)),
                            scroll
                        ) {
                            guard xcodeInspector.latestActiveXcode != nil else { return }
                            try Task.checkCancellation()
                            await send(.updateWindowLocation(animated: false))
                            await send(.updateWindowOpacity(immediately: false))
                        }
                    } else {
                        for await _ in merge(selectionRangeChange, scroll) {
                            guard xcodeInspector.latestActiveXcode != nil else { return }
                            try Task.checkCancellation()
                            await send(.updateWindowLocation(animated: false))
                            await send(.updateWindowOpacity(immediately: false))
                        }
                    }

                }.cancellable(id: CancelID.observeEditorChange, cancelInFlight: true)

            case .updateActiveApplication:
                if let app = xcodeInspector.activeApplication, app.isXcode {
                    return .run { send in
                        await send(.panel(.switchToAnotherEditorAndUpdateContent))
                        await send(.updateWindowLocation(animated: false))
                        await send(.updateWindowOpacity(immediately: true))
                        await windows.orderFront()
                        await send(.observeWindowChange)
                    }
                }
                return .run { send in
                    await send(.updateWindowLocation(animated: false))
                    await send(.updateWindowOpacity(immediately: true))
                }

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

            case let .updateWindowLocation(animated):
                guard let widgetLocation = generateWidgetLocation() else { return .none }
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

                let isChatPanelDetached = state.chatPanelState.chatPanelInASeparateWindow

                return .run { _ in
                    Task { @MainActor in
                        windows.widgetWindow.setFrame(
                            widgetLocation.widgetFrame,
                            display: false,
                            animate: animated
                        )
                        windows.toastWindow.setFrame(
                            widgetLocation.defaultPanelLocation.frame,
                            display: false,
                            animate: animated
                        )
                        windows.sharedPanelWindow.setFrame(
                            widgetLocation.defaultPanelLocation.frame,
                            display: false,
                            animate: animated
                        )

                        if let suggestionPanelLocation = widgetLocation.suggestionPanelLocation {
                            windows.suggestionPanelWindow.setFrame(
                                suggestionPanelLocation.frame,
                                display: false,
                                animate: animated
                            )
                        }

                        if isChatPanelDetached {
                            if windows.chatPanelWindow.alphaValue == 0 {
                                windows.chatPanelWindow.setFrame(
                                    widgetLocation.defaultPanelLocation.frame,
                                    display: false,
                                    animate: animated
                                )
                            }
                        } else {
                            windows.chatPanelWindow.setFrame(
                                widgetLocation.defaultPanelLocation.frame,
                                display: false,
                                animate: animated
                            )
                        }
                    }
                }

                #warning("TODO: control windows in their dedicated reducers.")
            case let .updateWindowOpacity(immediately):
                let isChatPanelDetached = state.chatPanelState.chatPanelInASeparateWindow
                let hasChat = !state.chatPanelState.chatTabGroup.tabInfo.isEmpty
                let shouldDebounce = !immediately &&
                    Date().timeIntervalSince(state.lastUpdateWindowOpacityTime) < 1
                return .run { send in
                    let activeApp = xcodeInspector.activeApplication
                    if shouldDebounce {
                        try await mainQueue.sleep(for: .seconds(0.2))
                    }
                    try Task.checkCancellation()
                    let task = Task { @MainActor in
                        if let activeApp, activeApp.isXcode {
                            let application = AXUIElementCreateApplication(
                                activeApp.runningApplication.processIdentifier
                            )
                            /// We need this to hide the windows when Xcode is minimized.
                            let noFocus = application.focusedWindow == nil
                            windows.sharedPanelWindow.alphaValue = noFocus ? 0 : 1
                            windows.suggestionPanelWindow.alphaValue = noFocus ? 0 : 1
                            windows.widgetWindow.alphaValue = noFocus ? 0 : 1
                            windows.toastWindow.alphaValue = noFocus ? 0 : 1

                            if isChatPanelDetached {
                                windows.chatPanelWindow.isWindowHidden = !hasChat
                            } else {
                                windows.chatPanelWindow.isWindowHidden = noFocus
                            }
                        } else if let activeApp, activeApp.isExtensionService {
                            let noFocus = {
                                guard let xcode = xcodeInspector.latestActiveXcode
                                else { return true }
                                if let window = xcode.appElement.focusedWindow,
                                   window.role == "AXWindow"
                                {
                                    return false
                                }
                                return true
                            }()

                            windows.sharedPanelWindow.alphaValue = noFocus ? 0 : 1
                            windows.suggestionPanelWindow.alphaValue = noFocus ? 0 : 1
                            windows.widgetWindow.alphaValue = noFocus ? 0 : 1
                            windows.toastWindow.alphaValue = noFocus ? 0 : 1
                            if isChatPanelDetached {
                                windows.chatPanelWindow.isWindowHidden = !hasChat
                            } else {
                                windows.chatPanelWindow.isWindowHidden = noFocus && !windows
                                    .chatPanelWindow.isKeyWindow
                            }
                        } else {
                            windows.sharedPanelWindow.alphaValue = 0
                            windows.suggestionPanelWindow.alphaValue = 0
                            windows.widgetWindow.alphaValue = 0
                            windows.toastWindow.alphaValue = 0
                            if !isChatPanelDetached {
                                windows.chatPanelWindow.isWindowHidden = true
                            }
                        }
                    }
                    _ = await task.value
                    await send(.updateWindowOpacityFinished)
                }
                .cancellable(id: DebounceKey.updateWindowOpacity, cancelInFlight: true)

            case .updateWindowOpacityFinished:
                state.lastUpdateWindowOpacityTime = Date()
                return .none

            case let .updateKeyWindow(window):
                return .run { _ in
                    switch window {
                    case .chatPanel:
                        await windows.chatPanelWindow.makeKeyAndOrderFront(nil)
                    case .sharedPanel:
                        await windows.sharedPanelWindow.makeKeyAndOrderFront(nil)
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

extension WidgetFeature {
    @MainActor
    func hidePanelWindows() {
        windows.sharedPanelWindow.alphaValue = 0
        windows.suggestionPanelWindow.alphaValue = 0
    }

    func generateWidgetLocation() -> WidgetLocation? {
        if let application = xcodeInspector.latestActiveXcode?.appElement {
            if let focusElement = xcodeInspector.focusedEditor?.element,
               let parent = focusElement.parent,
               let frame = parent.rect,
               let screen = NSScreen.screens.first(where: { $0.frame.origin == .zero }),
               let firstScreen = NSScreen.main
            {
                let positionMode = UserDefaults.shared
                    .value(for: \.suggestionWidgetPositionMode)
                let suggestionMode = UserDefaults.shared
                    .value(for: \.suggestionPresentationMode)

                switch positionMode {
                case .fixedToBottom:
                    var result = UpdateLocationStrategy.FixedToBottom().framesForWindows(
                        editorFrame: frame,
                        mainScreen: screen,
                        activeScreen: firstScreen
                    )
                    switch suggestionMode {
                    case .nearbyTextCursor:
                        result.suggestionPanelLocation = UpdateLocationStrategy
                            .NearbyTextCursor()
                            .framesForSuggestionWindow(
                                editorFrame: frame, mainScreen: screen,
                                activeScreen: firstScreen,
                                editor: focusElement,
                                completionPanel: xcodeInspector.completionPanel
                            )
                    default:
                        break
                    }
                    return result
                case .alignToTextCursor:
                    var result = UpdateLocationStrategy.AlignToTextCursor().framesForWindows(
                        editorFrame: frame,
                        mainScreen: screen,
                        activeScreen: firstScreen,
                        editor: focusElement
                    )
                    switch suggestionMode {
                    case .nearbyTextCursor:
                        result.suggestionPanelLocation = UpdateLocationStrategy
                            .NearbyTextCursor()
                            .framesForSuggestionWindow(
                                editorFrame: frame, mainScreen: screen,
                                activeScreen: firstScreen,
                                editor: focusElement,
                                completionPanel: xcodeInspector.completionPanel
                            )
                    default:
                        break
                    }
                    return result
                }
            } else if var window = application.focusedWindow,
                      var frame = application.focusedWindow?.rect,
                      !["menu bar", "menu bar item"].contains(window.description),
                      frame.size.height > 300,
                      let screen = NSScreen.screens.first(where: { $0.frame.origin == .zero }),
                      let firstScreen = NSScreen.main
            {
                if ["open_quickly"].contains(window.identifier)
                    || ["alert"].contains(window.label)
                {
                    // fallback to use workspace window
                    guard let workspaceWindow = application.windows
                        .first(where: { $0.identifier == "Xcode.WorkspaceWindow" }),
                        let rect = workspaceWindow.rect
                    else {
                        return WidgetLocation(
                            widgetFrame: .zero,
                            tabFrame: .zero,
                            defaultPanelLocation: .init(frame: .zero, alignPanelTop: false)
                        )
                    }

                    window = workspaceWindow
                    frame = rect
                }

                if ["Xcode.WorkspaceWindow"].contains(window.identifier) {
                    // extra padding to bottom so buttons won't be covered
                    frame.size.height -= 40
                } else {
                    // move a bit away from the window so buttons won't be covered
                    frame.origin.x -= Style.widgetPadding + Style.widgetWidth / 2
                    frame.size.width += Style.widgetPadding * 2 + Style.widgetWidth
                }

                return UpdateLocationStrategy.FixedToBottom().framesForWindows(
                    editorFrame: frame,
                    mainScreen: screen,
                    activeScreen: firstScreen,
                    preferredInsideEditorMinWidth: 9_999_999_999 // never
                )
            }
        }
        return nil
    }
}

