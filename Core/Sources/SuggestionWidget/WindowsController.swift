import AppKit
import AsyncAlgorithms
import ChatTab
import Combine
import ComposableArchitecture
import Dependencies
import Foundation
import SwiftUI
import XcodeInspector

final class WindowsController: NSObject {
    let userDefaultsObservers = WidgetUserDefaultsObservers()
    var xcodeInspector: XcodeInspector { .shared }

    let windows: WidgetWindows
    let store: StoreOf<WidgetFeature>
    let chatTabPool: ChatTabPool

    var currentApplicationProcessIdentifier: pid_t?

    var cancellable: Set<AnyCancellable> = []
    var observeToAppTask: Task<Void, Error>?
    var observeToFocusedEditorTask: Task<Void, Error>?
    var updateWindowOpacityTask: Task<Void, Error>?
    var lastUpdateWindowOpacityTime = Date(timeIntervalSince1970: 0)

    deinit {
        userDefaultsObservers.presentationModeChangeObserver.onChange = {}
        observeToAppTask?.cancel()
        observeToFocusedEditorTask?.cancel()
    }

    init(store: StoreOf<WidgetFeature>, chatTabPool: ChatTabPool) {
        self.store = store
        self.chatTabPool = chatTabPool
        windows = .init(store: store, chatTabPool: chatTabPool)
        super.init()
        windows.controller = self
    }

    @MainActor func send(_ action: WidgetFeature.Action) {
        store.send(action)
    }

    func start() {
        cancellable.removeAll()

        xcodeInspector.$activeApplication.sink { [weak self] app in
            guard let app else { return }
            self?.activate(app)
        }.store(in: &cancellable)

        xcodeInspector.$completionPanel.sink { [weak self] newValue in
            Task { [weak self] in
                if newValue == nil {
                    // so that the buttons on the suggestion panel could be
                    // clicked
                    // before the completion panel updates the location of the
                    // suggestion panel
                    try await Task.sleep(nanoseconds: 400_000_000)
                }
                await self?.updateWindowLocation(animated: false)
                await self?.updateWindowOpacity(immediately: false)
            }
        }.store(in: &cancellable)

        userDefaultsObservers.presentationModeChangeObserver.onChange = { [weak self] in
            Task { [weak self] in
                await self?.updateWindowLocation(animated: false)
                await self?.send(.updateColorScheme)
            }
        }
    }

    func updatePanelState(_ location: WidgetLocation) async {
        await send(.updatePanelStateToMatch(location))
    }

    func updateWindowOpacity(immediately: Bool) async {
        let state = store.withState { $0 }

        let isChatPanelDetached = state.chatPanelState.chatPanelInASeparateWindow
        let hasChat = !state.chatPanelState.chatTabGroup.tabInfo.isEmpty
        let shouldDebounce = !immediately &&
            Date().timeIntervalSince(lastUpdateWindowOpacityTime) < 1
        lastUpdateWindowOpacityTime = Date()
        let activeApp = xcodeInspector.activeApplication

        updateWindowOpacityTask?.cancel()

        let task = Task {
            if shouldDebounce {
                try await Task.sleep(nanoseconds: 200_000_000)
            }
            try Task.checkCancellation()
            await MainActor.run {
                if let activeApp, activeApp.isXcode {
                    let application = AXUIElementCreateApplication(
                        activeApp.processIdentifier
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
        }
        _ = try? await task.value
    }

    func updateWindowLocation(animated: Bool) async {
        let state = store.withState { $0 }

        guard let widgetLocation = generateWidgetLocation() else { return }
        await updatePanelState(widgetLocation)

        let isChatPanelDetached = state.chatPanelState.chatPanelInASeparateWindow

        await MainActor.run {
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
                // don't update it!
            } else {
                windows.chatPanelWindow.setFrame(
                    widgetLocation.defaultPanelLocation.frame,
                    display: false,
                    animate: animated
                )
            }
        }
    }
}

extension WindowsController: NSWindowDelegate {
    func windowWillMove(_ notification: Notification) {
        guard (notification.object as? NSWindow) === windows.chatPanelWindow else { return }
        Task { @MainActor in
            await Task.yield()
            store.send(.chatPanel(.detachChatPanel))
        }
    }

    func windowWillEnterFullScreen(_ notification: Notification) {
        guard (notification.object as? NSWindow) === windows.chatPanelWindow else { return }
        Task { @MainActor in
            await Task.yield()
            store.send(.chatPanel(.enterFullScreen))
        }
    }

    func windowWillExitFullScreen(_ notification: Notification) {
        guard (notification.object as? NSWindow) === windows.chatPanelWindow else { return }
        Task { @MainActor in
            await Task.yield()
            store.send(.chatPanel(.exitFullScreen))
        }
    }
}

private extension WindowsController {
    func activate(_ app: AppInstanceInspector) {
        guard currentApplicationProcessIdentifier != app.processIdentifier else { return }
        currentApplicationProcessIdentifier = app.processIdentifier
        observe(to: app)
    }

    func observe(to app: AppInstanceInspector) {
        guard let app = app as? XcodeAppInstanceInspector else {
            Task {
                await updateWindowLocation(animated: false)
                await updateWindowOpacity(immediately: true)
            }
            return
        }
        let notifications = app.axNotifications
        if let focusedEditor = xcodeInspector.focusedEditor {
            observe(to: focusedEditor)
        }
        observeToAppTask?.cancel()
        observeToAppTask = Task {
            await windows.orderFront()

            let documentURL = await MainActor.run { store.withState { $0.focusingDocumentURL } }
            for await notification in notifications {
                try Task.checkCancellation()

                // Hide the widgets before switching to another window/editor
                // so the transition looks better.
                if [
                    .focusedUIElementChanged,
                    .focusedWindowChanged,
                ].contains(notification.kind) {
                    let newDocumentURL = xcodeInspector.realtimeActiveDocumentURL
                    if documentURL != newDocumentURL {
                        await send(.panel(.removeDisplayedContent))
                        await hidePanelWindows()
                    }
                    await send(.updateFocusingDocumentURL)
                }

                // update widgets.
                if [
                    .focusedUIElementChanged,
                    .applicationActivated,
                    .mainWindowChanged,
                    .focusedWindowChanged,
                ].contains(notification.kind) {
                    await updateWindowLocation(animated: false)
                    await updateWindowOpacity(immediately: false)
                    if let editor = xcodeInspector.focusedEditor {
                        observe(to: editor)
                    }
                    await send(.panel(.switchToAnotherEditorAndUpdateContent))
                } else {
                    await updateWindowLocation(animated: false)
                    await updateWindowOpacity(immediately: false)
                }
            }
        }
    }

    func observe(to editor: SourceEditor) {
        observeToFocusedEditorTask?.cancel()
        observeToFocusedEditorTask = Task {
            let selectionRangeChange = editor.axNotifications
                .filter { $0.kind == .selectedTextChanged }
            let scroll = editor.axNotifications
                .filter { $0.kind == .scrollPositionChanged }

            if #available(macOS 13.0, *) {
                for await _ in merge(
                    selectionRangeChange.debounce(for: Duration.milliseconds(500)),
                    scroll
                ) {
                    guard xcodeInspector.latestActiveXcode != nil else { return }
                    try Task.checkCancellation()
                    await updateWindowLocation(animated: false)
                    await updateWindowOpacity(immediately: false)
                }
            } else {
                for await _ in merge(selectionRangeChange, scroll) {
                    guard xcodeInspector.latestActiveXcode != nil else { return }
                    try Task.checkCancellation()
                    await updateWindowLocation(animated: false)
                    await updateWindowOpacity(immediately: false)
                }
            }
        }
    }
}

extension WindowsController {
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

public final class WidgetWindows {
    let store: StoreOf<WidgetFeature>
    let chatTabPool: ChatTabPool
    weak var controller: WindowsController?

    // you should make these window `.transient` so they never show up in the mission control.

    @MainActor
    lazy var fullscreenDetector = {
        let it = CanBecomeKeyWindow(
            contentRect: .zero,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        it.isReleasedWhenClosed = false
        it.isOpaque = false
        it.backgroundColor = .clear
        it.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        it.hasShadow = false
        it.setIsVisible(false)
        it.canBecomeKeyChecker = { false }
        return it
    }()

    @MainActor
    lazy var widgetWindow = {
        let it = CanBecomeKeyWindow(
            contentRect: .zero,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        it.isReleasedWhenClosed = false
        it.isOpaque = false
        it.backgroundColor = .clear
        it.level = .floating
        it.collectionBehavior = [.fullScreenAuxiliary, .transient]
        it.hasShadow = true
        it.contentView = NSHostingView(
            rootView: WidgetView(
                store: store.scope(
                    state: \._circularWidgetState,
                    action: WidgetFeature.Action.circularWidget
                )
            )
        )
        it.setIsVisible(true)
        it.canBecomeKeyChecker = { false }
        return it
    }()

    @MainActor
    lazy var sharedPanelWindow = {
        let it = CanBecomeKeyWindow(
            contentRect: .init(x: 0, y: 0, width: Style.panelWidth, height: Style.panelHeight),
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        it.isReleasedWhenClosed = false
        it.isOpaque = false
        it.backgroundColor = .clear
        it.level = .init(NSWindow.Level.floating.rawValue + 2)
        it.collectionBehavior = [.fullScreenAuxiliary, .transient]
        it.hasShadow = true
        it.contentView = NSHostingView(
            rootView: SharedPanelView(
                store: store.scope(
                    state: \.panelState,
                    action: WidgetFeature.Action.panel
                ).scope(
                    state: \.sharedPanelState,
                    action: PanelFeature.Action.sharedPanel
                )
            )
        )
        it.setIsVisible(true)
        it.canBecomeKeyChecker = { [store] in
            store.withState { state in
                state.panelState.sharedPanelState.content.promptToCode != nil
            }
        }
        return it
    }()

    @MainActor
    lazy var suggestionPanelWindow = {
        let it = CanBecomeKeyWindow(
            contentRect: .init(x: 0, y: 0, width: Style.panelWidth, height: Style.panelHeight),
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        it.isReleasedWhenClosed = false
        it.isOpaque = false
        it.backgroundColor = .clear
        it.level = .init(NSWindow.Level.floating.rawValue + 2)
        it.collectionBehavior = [.fullScreenAuxiliary, .transient]
        it.hasShadow = true
        it.contentView = NSHostingView(
            rootView: SuggestionPanelView(
                store: store.scope(
                    state: \.panelState,
                    action: WidgetFeature.Action.panel
                ).scope(
                    state: \.suggestionPanelState,
                    action: PanelFeature.Action.suggestionPanel
                )
            )
        )
        it.canBecomeKeyChecker = { false }
        it.setIsVisible(true)
        return it
    }()

    @MainActor
    lazy var chatPanelWindow = {
        let it = ChatWindow(
            contentRect: .zero,
            styleMask: [.resizable, .titled, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        it.minimizeWindow = { [weak self] in
            self?.store.send(.chatPanel(.hideButtonClicked))
        }
        it.titleVisibility = .hidden
        it.addTitlebarAccessoryViewController({
            let controller = NSTitlebarAccessoryViewController()
            let view = NSHostingView(rootView: ChatTitleBar(store: store.scope(
                state: \.chatPanelState,
                action: WidgetFeature.Action.chatPanel
            )))
            controller.view = view
            view.frame = .init(x: 0, y: 0, width: 100, height: 40)
            controller.layoutAttribute = .right
            return controller
        }())
        it.titlebarAppearsTransparent = true
        it.isReleasedWhenClosed = false
        it.isOpaque = false
        it.backgroundColor = .clear
        it.level = .init(NSWindow.Level.floating.rawValue + 1)
        it.collectionBehavior = [
            .fullScreenAuxiliary,
            .transient,
            .fullScreenPrimary,
            .fullScreenAllowsTiling,
        ]
        it.hasShadow = true
        it.contentView = NSHostingView(
            rootView: ChatWindowView(
                store: store.scope(
                    state: \.chatPanelState,
                    action: WidgetFeature.Action.chatPanel
                ),
                toggleVisibility: { [weak it] isDisplayed in
                    guard let window = it else { return }
                    window.isPanelDisplayed = isDisplayed
                }
            )
            .environment(\.chatTabPool, chatTabPool)
        )
        it.setIsVisible(true)
        it.isPanelDisplayed = false
        it.delegate = controller
        return it
    }()

    @MainActor
    lazy var toastWindow = {
        let it = CanBecomeKeyWindow(
            contentRect: .zero,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        it.isReleasedWhenClosed = false
        it.isOpaque = true
        it.backgroundColor = .clear
        it.level = .floating
        it.collectionBehavior = [.fullScreenAuxiliary, .transient]
        it.hasShadow = false
        it.contentView = NSHostingView(
            rootView: ToastPanelView(store: store.scope(
                state: \.toastPanel,
                action: WidgetFeature.Action.toastPanel
            ))
        )
        it.setIsVisible(true)
        it.ignoresMouseEvents = true
        it.canBecomeKeyChecker = { false }
        return it
    }()

    init(
        store: StoreOf<WidgetFeature>,
        chatTabPool: ChatTabPool
    ) {
        self.store = store
        self.chatTabPool = chatTabPool
    }

    @MainActor
    func orderFront() {
        widgetWindow.orderFrontRegardless()
        toastWindow.orderFrontRegardless()
        sharedPanelWindow.orderFrontRegardless()
        suggestionPanelWindow.orderFrontRegardless()
        chatPanelWindow.orderFrontRegardless()
    }
}

// MARK: - Window Subclasses

class CanBecomeKeyWindow: NSWindow {
    var canBecomeKeyChecker: () -> Bool = { true }
    override var canBecomeKey: Bool { canBecomeKeyChecker() }
    override var canBecomeMain: Bool { canBecomeKeyChecker() }
}

class ChatWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    var minimizeWindow: () -> Void = {}

    var isWindowHidden: Bool = false {
        didSet {
            alphaValue = isPanelDisplayed && !isWindowHidden ? 1 : 0
        }
    }

    var isPanelDisplayed: Bool = false {
        didSet {
            alphaValue = isPanelDisplayed && !isWindowHidden ? 1 : 0
        }
    }

    override var alphaValue: CGFloat {
        didSet {
            ignoresMouseEvents = alphaValue <= 0
        }
    }

    override func miniaturize(_: Any?) {
        minimizeWindow()
    }
}

