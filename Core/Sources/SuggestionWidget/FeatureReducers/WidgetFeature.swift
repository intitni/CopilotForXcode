import ActiveApplicationMonitor
import AsyncAlgorithms
import AXNotificationStream
import ChatTab
import ComposableArchitecture
import Environment
import Foundation
import Preferences
import SwiftUI
import XcodeInspector

struct WidgetFeature: ReducerProtocol {
    struct WindowState: Equatable {
        var alphaValue: Double = 0
        var frame: CGRect = .zero
    }

    struct Windows: Equatable {
        var widgetWindowState = WindowState()
        var chatWindowState = WindowState()
        var suggestionPanelWindowState = WindowState()
        var sharedPanelWindowState = WindowState()
        var tabWindowState = WindowState()
    }

    struct State: Equatable {
        var colorScheme: ColorScheme = .light

        // MARK: Panels

        var panelState = PanelFeature.State()

        // MARK: ChatPanel

        var chatPanelState = ChatPanelFeature.State()

        // MARK: CircularWidget

        struct CircularWidgetState: Equatable {
            var isProcessingCounters = [CircularWidgetFeature.IsProcessingCounter]()
            var isProcessing: Bool = false
            var animationProgress: Double = 0
        }

        var circularWidgetState = CircularWidgetState()
        var _circularWidgetState: CircularWidgetFeature.State {
            get {
                .init(
                    isProcessingCounters: circularWidgetState.isProcessingCounters,
                    isProcessing: circularWidgetState.isProcessing,
                    isDisplayingContent: {
                        if chatPanelState.isPanelDisplayed, chatPanelState.chat != nil {
                            return true
                        }
                        if panelState.sharedPanelState.isPanelDisplayed,
                           panelState.sharedPanelState.content != nil
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
                    isContentEmpty: chatPanelState.chat == nil && panelState.sharedPanelState
                        .content == nil,
                    isChatPanelDetached: chatPanelState.chatPanelInASeparateWindow,
                    isChatOpen: chatPanelState.isPanelDisplayed && chatPanelState.chat != nil,
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
    }

    private enum CancelID {
        case observeActiveApplicationChange
        case observeCompletionPanelChange
        case observeFullscreenChange
        case observeWindowChange
        case observeEditorChange
        case observeUserDefaults
    }

    enum Action: Equatable {
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
        case updateWindowOpacity

        case panel(PanelFeature.Action)
        case chatPanel(ChatPanelFeature.Action)
        case circularWidget(CircularWidgetFeature.Action)
    }

    @Dependency(\.windows) var windows
    @Dependency(\.userDefaultsObservers) var userDefaultsObservers
    @Dependency(\.suggestionWidgetControllerDependency) var suggestionWidgetControllerDependency
    @Dependency(\.activeApplicationMonitor) var activeApplicationMonitor
    @Dependency(\.xcodeInspector) var xcodeInspector

    var body: some ReducerProtocol<State, Action> {
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
                let isDisplayingContent = state._circularWidgetState.isDisplayingContent
                if isDisplayingContent {
                    state.panelState.sharedPanelState.isPanelDisplayed = false
                    state.panelState.suggestionPanelState.isPanelDisplayed = false
                    state.chatPanelState.isPanelDisplayed = false
                } else {
                    state.panelState.sharedPanelState.isPanelDisplayed = true
                    state.panelState.suggestionPanelState.isPanelDisplayed = true
                    state.chatPanelState.isPanelDisplayed = true
                }
                return .run { _ in
                    guard isDisplayingContent else { return }
                    if let app = activeApplicationMonitor.previousActiveApplication, app.isXcode {
                        try await Task.sleep(nanoseconds: 200_000_000)
                        app.activate()
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
                    await send(.updateWindowOpacity)
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
                    await send(.updateWindowOpacity)
                }
            default: return .none
            }
        }

        Reduce { state, action in
            switch action {
            case .startup:
                return .merge(
                    .run { send in await send(.observeActiveApplicationChange) },
                    .run { send in await send(.observeCompletionPanelChange) },
                    .run { send in await send(.observeFullscreenChange) },
                    .run { send in await send(.observeColorSchemeChange) },
                    .run { send in await send(.observePresentationModeChange) }
                )

            case .observeActiveApplicationChange:
                return .run { send in
                    var previousApp: NSRunningApplication?
                    for await app in activeApplicationMonitor.createStream() {
                        try Task.checkCancellation()
                        if app != previousApp {
                            await send(.updateActiveApplication)
                        }
                        previousApp = app
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
                                    try await Task.sleep(nanoseconds: 200_000_000)
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
                        await send(.updateWindowOpacity)
                    }
                }.cancellable(id: CancelID.observeCompletionPanelChange, cancelInFlight: true)

            case .observeFullscreenChange:
                return .run { _ in
                    let sequence = NSWorkspace.shared.notificationCenter
                        .notifications(named: NSWorkspace.activeSpaceDidChangeNotification)
                    for await _ in sequence {
                        try Task.checkCancellation()
                        guard let activeXcode = activeApplicationMonitor.activeXcode
                        else { continue }
                        guard await windows.fullscreenDetector.isOnActiveSpace else { continue }
                        let app = AXUIElementCreateApplication(activeXcode.processIdentifier)
                        if let window = app.focusedWindow, window.isFullScreen {
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
                guard let app = activeApplicationMonitor.activeApplication else { return .none }
                guard app.isXcode else { return .none }

                return .run { send in
                    await send(.observeEditorChange)

                    let notifications = AXNotificationStream(
                        app: app,
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
                    for await notification in notifications {
                        try Task.checkCancellation()

                        if [
                            kAXFocusedUIElementChangedNotification,
                            kAXApplicationActivatedNotification,
                            kAXMainWindowChangedNotification,
                            kAXFocusedWindowChangedNotification,
                        ].contains(notification.name) {
                            await hidePanelWindows()
                            await send(.panel(.removeDisplayedContent))
                            await send(.updateWindowLocation(animated: false))
                            await send(.updateWindowOpacity)
                            await send(.observeEditorChange)
                            await send(.panel(.switchToAnotherEditorAndUpdateContent))
                            await send(.chatPanel(.updateContent))
                        } else {
                            await send(.updateWindowLocation(animated: false))
                            await send(.updateWindowOpacity)
                        }
                    }
                }.cancellable(id: CancelID.observeWindowChange, cancelInFlight: true)

            case .observeEditorChange:
                guard let app = activeApplicationMonitor.activeApplication else { return .none }
                return .run { send in
                    let appElement = AXUIElementCreateApplication(app.processIdentifier)
                    if let focusedElement = appElement.focusedElement,
                       focusedElement.description == "Source Editor",
                       let scrollView = focusedElement.parent,
                       let scrollBar = scrollView.verticalScrollBar
                    {
                        let selectionRangeChange = AXNotificationStream(
                            app: app,
                            element: focusedElement,
                            notificationNames: kAXSelectedTextChangedNotification
                        )
                        let scroll = AXNotificationStream(
                            app: app,
                            element: scrollBar,
                            notificationNames: kAXValueChangedNotification
                        )

                        if #available(macOS 13.0, *) {
                            for await _ in merge(
                                selectionRangeChange.debounce(for: Duration.milliseconds(500)),
                                scroll
                            ) {
                                guard activeApplicationMonitor.latestXcode != nil
                                else { return }
                                try Task.checkCancellation()
                                await send(.updateWindowLocation(animated: false))
                                await send(.updateWindowOpacity)
                            }
                        } else {
                            for await _ in merge(selectionRangeChange, scroll) {
                                guard activeApplicationMonitor.latestXcode != nil
                                else { return }
                                try Task.checkCancellation()
                                await send(.updateWindowLocation(animated: false))
                                await send(.updateWindowOpacity)
                            }
                        }
                    }
                }.cancellable(id: CancelID.observeEditorChange, cancelInFlight: true)

            case .updateActiveApplication:
                if let app = activeApplicationMonitor.activeApplication, app.isXcode {
                    return .run { send in
                        await send(.panel(.switchToAnotherEditorAndUpdateContent))
                        await send(.chatPanel(.updateContent))
                        await send(.updateWindowLocation(animated: false))
                        await send(.updateWindowOpacity)
                        await windows.orderFront()
                        await send(.observeWindowChange)
                    }
                }
                return .run { send in
                    await send(.updateWindowLocation(animated: false))
                    await send(.updateWindowOpacity)
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
                state.panelState.sharedPanelState.colorScheme = scheme
                state.panelState.suggestionPanelState.colorScheme = scheme
                state.chatPanelState.colorScheme = scheme
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

                let isChatPanelDetached = state.chatPanelState.chatPanelInASeparateWindow

                return .run { _ in
                    Task { @MainActor in
                        windows.widgetWindow.setFrame(
                            widgetLocation.widgetFrame,
                            display: false,
                            animate: animated
                        )
                        windows.tabWindow.setFrame(
                            widgetLocation.tabFrame,
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

            case .updateWindowOpacity:
                let isChatPanelDetached = state.chatPanelState.chatPanelInASeparateWindow
                let hasChat = state.chatPanelState.chat != nil

                return .run { _ in
                    Task { @MainActor in
                        if let app = activeApplicationMonitor.activeApplication, app.isXcode {
                            let application = AXUIElementCreateApplication(app.processIdentifier)
                            /// We need this to hide the windows when Xcode is minimized.
                            let noFocus = application.focusedWindow == nil
                            windows.sharedPanelWindow.alphaValue = noFocus ? 0 : 1
                            windows.suggestionPanelWindow.alphaValue = noFocus ? 0 : 1
                            windows.widgetWindow.alphaValue = noFocus ? 0 : 1
                            windows.tabWindow.alphaValue = noFocus ? 0 : 1

                            if isChatPanelDetached {
                                windows.chatPanelWindow.alphaValue = hasChat ? 1 : 0
                            } else {
                                windows.chatPanelWindow.alphaValue = noFocus ? 0 : 1
                            }
                        } else if let app = activeApplicationMonitor.activeApplication,
                                  app.bundleIdentifier == Bundle.main.bundleIdentifier
                        {
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
                            windows.tabWindow.alphaValue = noFocus ? 0 : 1
                            if isChatPanelDetached {
                                windows.chatPanelWindow.alphaValue = hasChat ? 1 : 0
                            } else {
                                windows.chatPanelWindow.alphaValue = noFocus && !windows
                                    .chatPanelWindow.isKeyWindow ? 0 : 1
                            }
                        } else {
                            windows.sharedPanelWindow.alphaValue = 0
                            windows.suggestionPanelWindow.alphaValue = 0
                            windows.widgetWindow.alphaValue = 0
                            windows.tabWindow.alphaValue = 0
                            if !isChatPanelDetached {
                                windows.chatPanelWindow.alphaValue = 0
                            }
                        }
                    }
                }

            case let .circularWidget(action):
                switch action {
                case .openChatButtonClicked:
                    suggestionWidgetControllerDependency.onOpenChatClicked()
                    return .none

                case let .runCustomCommandButtonClicked(command):
                    suggestionWidgetControllerDependency.onCustomCommandClicked(command)
                    return .none

                default:
                    return .none
                }

            case .panel:
                return .none

            case .chatPanel:
                return .none
            }
        }
    }

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

