import ActiveApplicationMonitor
import AppKit
import AsyncAlgorithms
import AXNotificationStream
import Combine
import Environment
import Preferences
import SwiftUI
import UserDefaultsObserver
import XcodeInspector

@MainActor
public final class SuggestionWidgetController: NSObject {
    // you should make these window `.transient` so they never show up in the mission control.

    private lazy var fullscreenDetector = {
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

    private lazy var widgetWindow = {
        let it = CanBecomeKeyWindow(
            contentRect: .zero,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        it.isReleasedWhenClosed = false
        it.isOpaque = false
        it.backgroundColor = .clear
        it.level = .init(19)
        it.collectionBehavior = [.fullScreenAuxiliary, .transient]
        it.hasShadow = true
        it.contentView = NSHostingView(
            rootView: WidgetView(
                viewModel: widgetViewModel,
                panelViewModel: sharedPanelViewModel,
                chatWindowViewModel: chatWindowViewModel,
                sharedPanelDisplayController: sharedPanelDisplayController,
                suggestionPanelDisplayController: suggestionPanelDisplayController,
                onOpenChatClicked: { [weak self] in
                    self?.onOpenChatClicked()
                },
                onCustomCommandClicked: { [weak self] command in
                    self?.onCustomCommandClicked(command)
                }
            )
        )
        it.setIsVisible(true)
        it.canBecomeKeyChecker = { false }
        return it
    }()

    private lazy var tabWindow = {
        let it = CanBecomeKeyWindow(
            contentRect: .zero,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        it.isReleasedWhenClosed = false
        it.isOpaque = false
        it.backgroundColor = .clear
        it.level = .init(19)
        it.collectionBehavior = [.fullScreenAuxiliary, .transient]
        it.hasShadow = true
        it.contentView = NSHostingView(
            rootView: TabView(chatWindowViewModel: chatWindowViewModel)
        )
        it.setIsVisible(true)
        it.canBecomeKeyChecker = { false }
        return it
    }()

    private lazy var panelWindow = {
        let it = CanBecomeKeyWindow(
            contentRect: .init(x: 0, y: 0, width: Style.panelWidth, height: Style.panelHeight),
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        it.isReleasedWhenClosed = false
        it.isOpaque = false
        it.backgroundColor = .clear
        it.level = .init(NSWindow.Level.floating.rawValue + 1)
        it.collectionBehavior = [.fullScreenAuxiliary, .transient]
        it.hasShadow = true
        it.contentView = NSHostingView(
            rootView: SharedPanelView(
                viewModel: sharedPanelViewModel,
                displayController: sharedPanelDisplayController
            )
        )
        it.setIsVisible(true)
        it.canBecomeKeyChecker = { [sharedPanelViewModel] in
            if case .promptToCode = sharedPanelViewModel.content { return true }
            return false
        }
        return it
    }()

    private lazy var suggestionWindow = {
        let it = CanBecomeKeyWindow(
            contentRect: .init(x: 0, y: 0, width: Style.panelWidth, height: Style.panelHeight),
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        it.isReleasedWhenClosed = false
        it.isOpaque = false
        it.backgroundColor = .clear
        it.level = .init(NSWindow.Level.floating.rawValue - 1)
        it.collectionBehavior = [.fullScreenAuxiliary, .transient]
        it.hasShadow = true
        it.contentView = NSHostingView(
            rootView: SuggestionPanelView(
                viewModel: sharedPanelViewModel,
                displayController: suggestionPanelDisplayController
            )
        )
        it.setIsVisible(true)
        it.canBecomeKeyChecker = { [sharedPanelViewModel] in
            if case .promptToCode = sharedPanelViewModel.content { return true }
            return false
        }
        return it
    }()

    private lazy var chatWindow = {
        let it = ChatWindow(
            contentRect: .zero,
            styleMask: [.resizable],
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
            rootView: ChatWindowView(viewModel: chatWindowViewModel)
        )
        it.setIsVisible(true)
        it.delegate = self
        return it
    }()

    let widgetViewModel = WidgetViewModel()
    let sharedPanelViewModel = SharedPanelViewModel()
    let chatWindowViewModel = ChatWindowViewModel()
    let sharedPanelDisplayController = SharedPanelDisplayController()
    let suggestionPanelDisplayController = SuggestionPanelDisplayController()

    private var presentationModeChangeObserver = UserDefaultsObserver(
        object: UserDefaults.shared,
        forKeyPaths: [
            UserDefaultPreferenceKeys().suggestionPresentationMode.key,
        ], context: nil
    )
    private var colorSchemeChangeObserver = UserDefaultsObserver(
        object: UserDefaults.shared, forKeyPaths: [
            UserDefaultPreferenceKeys().widgetColorScheme.key,
        ], context: nil
    )
    private var systemColorSchemeChangeObserver = UserDefaultsObserver(
        object: UserDefaults.standard, forKeyPaths: ["AppleInterfaceStyle"], context: nil
    )
    private var windowChangeObservationTask: Task<Void, Error>?
    private var activeApplicationMonitorTask: Task<Void, Error>?
    private var sourceEditorMonitorTask: Task<Void, Error>?
    private var fullscreenDetectingTask: Task<Void, Error>?
    private var currentFileURL: URL?
    private var colorScheme: ColorScheme = .light
    private var cancellable = Set<AnyCancellable>()

    public var onOpenChatClicked: () -> Void = {}
    public var onCustomCommandClicked: (CustomCommand) -> Void = { _ in }
    public var dataSource: SuggestionWidgetDataSource?

    override public nonisolated init() {
        super.init()
        #warning(
            "TODO: A test is initializing this class for unknown reasons, try a better way to avoid this."
        )
        if ProcessInfo.processInfo.environment["IS_UNIT_TEST"] == "YES" { return }

        Task { @MainActor in
            activeApplicationMonitorTask = Task { [weak self] in
                var previousApp: NSRunningApplication?
                for await app in ActiveApplicationMonitor.createStream() {
                    guard let self else { return }
                    try Task.checkCancellation()
                    defer { previousApp = app }
                    if let app = ActiveApplicationMonitor.activeXcode {
                        if app != previousApp {
                            windowChangeObservationTask?.cancel()
                            windowChangeObservationTask = nil
                            observeXcodeWindowChangeIfNeeded(app)
                        }
                        await updateContentForActiveEditor()
                        updateWindowLocation()
                        orderFront()
                    } else {
                        if ActiveApplicationMonitor.activeApplication?.bundleIdentifier != Bundle
                            .main.bundleIdentifier
                        {
                            self.widgetWindow.alphaValue = 0
                            self.panelWindow.alphaValue = 0
                            self.tabWindow.alphaValue = 0
                            self.suggestionWindow.alphaValue = 0
                            if !chatWindowViewModel.chatPanelInASeparateWindow {
                                self.chatWindow.alphaValue = 0
                            }
                        }
                    }
                }
            }

            fullscreenDetectingTask = Task { [weak self] in
                let sequence = NSWorkspace.shared.notificationCenter
                    .notifications(named: NSWorkspace.activeSpaceDidChangeNotification)
                _ = self?.fullscreenDetector
                for await _ in sequence {
                    try Task.checkCancellation()
                    guard let self else { return }
                    guard let activeXcode = ActiveApplicationMonitor.activeXcode else { continue }
                    guard fullscreenDetector.isOnActiveSpace else { continue }
                    let app = AXUIElementCreateApplication(activeXcode.processIdentifier)
                    if let window = app.focusedWindow, window.isFullScreen {
                        orderFront()
                    }
                }
            }

            presentationModeChangeObserver.onChange = { [weak self] in
                guard let self else { return }
                self.updateWindowLocation()
            }

            chatWindowViewModel.$chatPanelInASeparateWindow.dropFirst().removeDuplicates()
                .sink { [weak self] _ in
                    guard let self else { return }
                    Task { @MainActor in
                        self.updateWindowLocation(animated: true)
                    }
                }.store(in: &cancellable)

            let updateColorScheme = { @MainActor [weak self] in
                guard let self else { return }
                let widgetColorScheme = UserDefaults.shared.value(for: \.widgetColorScheme)
                let systemColorScheme: ColorScheme = NSApp.effectiveAppearance.name == .darkAqua
                    ? .dark
                    : .light
                self.colorScheme = {
                    switch (widgetColorScheme, systemColorScheme) {
                    case (.system, .dark), (.dark, _):
                        return .dark
                    case (.system, .light), (.light, _):
                        return .light
                    case (.system, _):
                        return .light
                    }
                }()
                self.sharedPanelViewModel.colorScheme = self.colorScheme
                self.chatWindowViewModel.colorScheme = self.colorScheme
                Task {
                    await self.updateContentForActiveEditor()
                }
            }

            updateColorScheme()
            colorSchemeChangeObserver.onChange = {
                updateColorScheme()
            }
            systemColorSchemeChangeObserver.onChange = {
                updateColorScheme()
            }

            XcodeInspector.shared.$completionPanel.sink { [weak self] newValue in
                Task { @MainActor in
                    if newValue == nil {
                        // so that the buttons on the suggestion panel could be clicked
                        // before the completion panel updates the location of the suggestion panel
                        try await Task.sleep(nanoseconds: 200_000_000)
                    }
                    self?.updateWindowLocation()
                }
            }.store(in: &cancellable)
        }
    }

    func orderFront() {
        widgetWindow.orderFrontRegardless()
        tabWindow.orderFrontRegardless()
        panelWindow.orderFrontRegardless()
        suggestionWindow.orderFrontRegardless()
        chatWindow.orderFrontRegardless()
    }
}

// MARK: - Handle Events

public extension SuggestionWidgetController {
    func suggestCode(fileURL: URL) {
        Task {
            markAsProcessing(true)
            defer { markAsProcessing(false) }
            if let suggestion = await dataSource?.suggestionForFile(at: fileURL) {
                sharedPanelViewModel.content = .suggestion(suggestion)
                switch UserDefaults.shared.value(for: \.suggestionPresentationMode) {
                case .nearbyTextCursor:
                    suggestionPanelDisplayController.isPanelDisplayed = true
                case .floatingWidget:
                    sharedPanelDisplayController.isPanelDisplayed = true
                }
            }
        }
    }

    func discardSuggestion(fileURL: URL) {
        Task {
            await updateContentForActiveEditor(fileURL: fileURL)
        }
    }

    func markAsProcessing(_ isProcessing: Bool) {
        if isProcessing {
            widgetViewModel.markIsProcessing()
        } else {
            widgetViewModel.endIsProcessing()
        }
    }

    func presentError(_ errorDescription: String) {
        sharedPanelViewModel.content = .error(errorDescription)
        sharedPanelDisplayController.isPanelDisplayed = true
    }

    func presentChatRoom(fileURL: URL) {
        Task {
            markAsProcessing(true)
            defer { markAsProcessing(false) }
            if let chat = await dataSource?.chatForFile(at: fileURL) {
                chatWindowViewModel.chat = chat
                chatWindowViewModel.isPanelDisplayed = true

                if chatWindowViewModel.chatPanelInASeparateWindow {
                    self.updateWindowLocation()
                }

                Task { @MainActor in
                    // looks like we need a delay.
                    try await Task.sleep(nanoseconds: 150_000_000)
                    NSApplication.shared.activate(ignoringOtherApps: true)
                }
            }
        }
    }

    func presentDetachedGlobalChat() {
        chatWindowViewModel.chatPanelInASeparateWindow = true
        Task {
            if let chat = await dataSource?.chatForFile(at: URL(fileURLWithPath: "/")) {
                chatWindowViewModel.chat = chat
                chatWindowViewModel.isPanelDisplayed = true

                if chatWindowViewModel.chatPanelInASeparateWindow {
                    self.updateWindowLocation()
                }

                Task { @MainActor in
                    chatWindow.alphaValue = 1
                    // looks like we need a delay.
                    try await Task.sleep(nanoseconds: 150_000_000)
                    NSApplication.shared.activate(ignoringOtherApps: true)
                }
            }
        }
    }

    func closeChatRoom(fileURL: URL) {
        Task {
            await updateContentForActiveEditor(fileURL: fileURL)
        }
    }

    func presentPromptToCode(fileURL: URL) {
        Task {
            markAsProcessing(true)
            defer { markAsProcessing(false) }
            if let provider = await dataSource?.promptToCodeForFile(at: fileURL) {
                sharedPanelViewModel.content = .promptToCode(provider)
                sharedPanelDisplayController.isPanelDisplayed = true

                Task { @MainActor in
                    // looks like we need a delay.
                    try await Task.sleep(nanoseconds: 150_000_000)
                    NSApplication.shared.activate(ignoringOtherApps: true)
                    panelWindow.makeKey()
                }
            }
        }
    }

    func discardPromptToCode(fileURL: URL) {
        Task {
            await updateContentForActiveEditor(fileURL: fileURL)
        }
    }
}

// MARK: - Private

extension SuggestionWidgetController {
    private func observeXcodeWindowChangeIfNeeded(_ app: NSRunningApplication) {
        guard windowChangeObservationTask == nil else { return }
        observeEditorChangeIfNeeded(app)
        windowChangeObservationTask = Task { [weak self] in
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
                guard let self else { return }
                try Task.checkCancellation()

                self.updateWindowLocation(animated: false)

                if [
                    kAXFocusedUIElementChangedNotification,
                    kAXApplicationActivatedNotification,
                ].contains(notification.name) {
                    sourceEditorMonitorTask?.cancel()
                    sourceEditorMonitorTask = nil
                    observeEditorChangeIfNeeded(app)

                    guard let fileURL = try? await Environment.fetchFocusedElementURI() else {
                        continue
                    }

                    guard fileURL != currentFileURL else { continue }
                    currentFileURL = fileURL
                    widgetViewModel.currentFileURL = currentFileURL
                    await updateContentForActiveEditor(fileURL: fileURL)
                }
            }
        }
    }

    private func observeEditorChangeIfNeeded(_ app: NSRunningApplication) {
        guard sourceEditorMonitorTask == nil else { return }
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        if let focusedElement = appElement.focusedElement,
           focusedElement.description == "Source Editor",
           let scrollView = focusedElement.parent,
           let scrollBar = scrollView.verticalScrollBar
        {
            sourceEditorMonitorTask = Task { [weak self] in
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
                        guard let self else { return }
                        guard ActiveApplicationMonitor.latestXcode != nil else { return }
                        try Task.checkCancellation()
                        self.updateWindowLocation(animated: false)
                    }
                } else {
                    for await _ in merge(selectionRangeChange, scroll) {
                        guard let self else { return }
                        guard ActiveApplicationMonitor.latestXcode != nil else { return }
                        try Task.checkCancellation()
                        let mode = UserDefaults.shared.value(for: \.suggestionWidgetPositionMode)
                        if mode != .alignToTextCursor { break }
                        self.updateWindowLocation(animated: false)
                    }
                }
            }
        }
    }

    /// Update the window location.
    ///
    /// - note: It's possible to get the scroll view's position by getting position on the focus
    /// element.
    private func updateWindowLocation(animated: Bool = false) {
        let detachChat = chatWindowViewModel.chatPanelInASeparateWindow

        if let widgetLocation = generateWidgetLocation() {
            widgetWindow.setFrame(widgetLocation.widgetFrame, display: false, animate: animated)
            tabWindow.setFrame(widgetLocation.tabFrame, display: false, animate: animated)
            panelWindow.setFrame(
                widgetLocation.defaultPanelLocation.frame,
                display: false,
                animate: animated
            )

            sharedPanelDisplayController.alignTopToAnchor = widgetLocation.defaultPanelLocation
                .alignPanelTop

            if let suggestionPanelLocation = widgetLocation.suggestionPanelLocation {
                suggestionWindow.setFrame(
                    suggestionPanelLocation.frame,
                    display: false,
                    animate: animated
                )
                suggestionPanelDisplayController.isPanelOutOfFrame = false
                suggestionPanelDisplayController.alignTopToAnchor = suggestionPanelLocation
                    .alignPanelTop
            } else {
                suggestionPanelDisplayController.isPanelOutOfFrame = true
            }

            if detachChat {
                if chatWindow.alphaValue == 0 {
                    chatWindow.setFrame(
                        widgetLocation.defaultPanelLocation.frame,
                        display: false,
                        animate: animated
                    )
                }
            } else {
                chatWindow.setFrame(
                    widgetLocation.defaultPanelLocation.frame,
                    display: false,
                    animate: animated
                )
            }
        }

        if let app = ActiveApplicationMonitor.activeApplication, app.isXcode {
            let application = AXUIElementCreateApplication(app.processIdentifier)
            /// We need this to hide the windows when Xcode is minimized.
            let noFocus = application.focusedWindow == nil
            panelWindow.alphaValue = noFocus ? 0 : 1
            suggestionWindow.alphaValue = noFocus ? 0 : 1
            widgetWindow.alphaValue = noFocus ? 0 : 1
            tabWindow.alphaValue = noFocus ? 0 : 1

            if detachChat {
                chatWindow.alphaValue = chatWindowViewModel.chat != nil ? 1 : 0
            } else {
                chatWindow.alphaValue = noFocus ? 0 : 1
            }
        } else if let app = ActiveApplicationMonitor.activeApplication,
                  app.bundleIdentifier == Bundle.main.bundleIdentifier
        {
            let noFocus = {
                guard let xcode = ActiveApplicationMonitor.latestXcode else { return true }
                let application = AXUIElementCreateApplication(xcode.processIdentifier)
                return application
                    .focusedWindow == nil || (application.focusedWindow?.role == "AXWindow")
            }()

            panelWindow.alphaValue = noFocus ? 0 : 1
            suggestionWindow.alphaValue = noFocus ? 0 : 1
            widgetWindow.alphaValue = noFocus ? 0 : 1
            tabWindow.alphaValue = noFocus ? 0 : 1
            if detachChat {
                chatWindow.alphaValue = chatWindowViewModel.chat != nil ? 1 : 0
            } else {
                chatWindow.alphaValue = noFocus && !chatWindow.isKeyWindow ? 0 : 1
            }
        } else {
            panelWindow.alphaValue = 0
            suggestionWindow.alphaValue = 0
            widgetWindow.alphaValue = 0
            tabWindow.alphaValue = 0
            if !detachChat {
                chatWindow.alphaValue = 0
            }
        }
    }

    private func updateContentForActiveEditor(fileURL: URL? = nil) async {
        guard let fileURL = await {
            if let fileURL { return fileURL }
            return try? await Environment.fetchCurrentFileURL()
        }() else {
            sharedPanelViewModel.content = nil
            chatWindowViewModel.chat = nil
            return
        }

        if let chat = await dataSource?.chatForFile(at: fileURL) {
            if chatWindowViewModel.chat?.id != chat.id {
                chatWindowViewModel.chat = chat
            }
        } else {
            chatWindowViewModel.chat = nil
        }

        if let provider = await dataSource?.promptToCodeForFile(at: fileURL) {
            if case let .promptToCode(currentProvider) = sharedPanelViewModel.content,
               currentProvider.id == provider.id { return }
            sharedPanelViewModel.content = .promptToCode(provider)
        } else if let suggestion = await dataSource?.suggestionForFile(at: fileURL) {
            sharedPanelViewModel.content = .suggestion(suggestion)
        } else {
            sharedPanelViewModel.content = nil
        }
    }

    private func generateWidgetLocation() -> WidgetLocation? {
        if let application = XcodeInspector.shared.latestActiveXcode?.appElement {
            if let focusElement = XcodeInspector.shared.focusedEditor?.element,
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
                                completionPanel: XcodeInspector.shared.completionPanel
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
                                completionPanel: XcodeInspector.shared.completionPanel
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

// MARK: - NSWindowDelegate

extension SuggestionWidgetController: NSWindowDelegate {
    public func windowWillMove(_ notification: Notification) {
        guard (notification.object as? NSWindow) === chatWindow else { return }
        Task { @MainActor in
            await Task.yield()
            chatWindowViewModel.chatPanelInASeparateWindow = true
        }
    }

    public func windowDidBecomeKey(_ notification: Notification) {
        guard (notification.object as? NSWindow) === chatWindow else { return }
        let screenFrame = NSScreen.screens.first(where: { $0.frame.origin == .zero })?
            .frame ?? .zero
        var mouseLocation = NSEvent.mouseLocation
        let windowFrame = chatWindow.frame
        if mouseLocation.y > windowFrame.maxY - 40,
           mouseLocation.y < windowFrame.maxY,
           mouseLocation.x > windowFrame.minX,
           mouseLocation.x < windowFrame.maxX
        {
            mouseLocation.y = screenFrame.size.height - mouseLocation.y
            if let cgEvent = CGEvent(
                mouseEventSource: nil,
                mouseType: .leftMouseDown,
                mouseCursorPosition: mouseLocation,
                mouseButton: .left
            ),
                let event = NSEvent(cgEvent: cgEvent)
            {
                chatWindow.performDrag(with: event)
            }
        }
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

    override func mouseDown(with event: NSEvent) {
        let windowFrame = frame
        let currentLocation = event.locationInWindow
        if currentLocation.y > windowFrame.size.height - 40,
           currentLocation.y < windowFrame.size.height,
           currentLocation.x > 0,
           currentLocation.x < windowFrame.width
        {
            performDrag(with: event)
        }
    }
}

