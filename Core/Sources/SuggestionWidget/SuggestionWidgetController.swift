import ActiveApplicationMonitor
import AppKit
import AsyncAlgorithms
import AXNotificationStream
import Environment
import Preferences
import SwiftUI

@MainActor
public final class SuggestionWidgetController: NSObject {
    class UserDefaultsObserver: NSObject {
        var onChange: (() -> Void)?

        override func observeValue(
            forKeyPath keyPath: String?,
            of object: Any?,
            change: [NSKeyValueChangeKey: Any]?,
            context: UnsafeMutableRawPointer?
        ) {
            onChange?()
        }
    }

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
        it.level = .init(NSWindow.Level.floating.rawValue + 1)
        it.hasShadow = true
        it.contentView = NSHostingView(
            rootView: WidgetView(
                viewModel: widgetViewModel,
                panelViewModel: suggestionPanelViewModel,
                chatWindowViewModel: chatWindowViewModel,
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
        it.level = .init(NSWindow.Level.floating.rawValue + 1)
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
            contentRect: .zero,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        it.isReleasedWhenClosed = false
        it.isOpaque = false
        it.backgroundColor = .clear
        it.level = .init(NSWindow.Level.floating.rawValue + 1)
        it.hasShadow = true
        it.contentView = NSHostingView(
            rootView: SuggestionPanelView(viewModel: suggestionPanelViewModel)
        )
        it.setIsVisible(true)
        it.canBecomeKeyChecker = { [suggestionPanelViewModel] in
            if case .promptToCode = suggestionPanelViewModel.content { return true }
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
        it.hasShadow = true
        it.contentView = NSHostingView(
            rootView: ChatWindowView(viewModel: chatWindowViewModel)
        )
        it.setIsVisible(true)
        it.delegate = self
        return it
    }()

    let widgetViewModel = WidgetViewModel()
    let suggestionPanelViewModel = SuggestionPanelViewModel()
    let chatWindowViewModel = ChatWindowViewModel()

    private var presentationModeChangeObserver = UserDefaultsObserver()
    private var colorSchemeChangeObserver = UserDefaultsObserver()
    private var detachChatPanelObserver = UserDefaultsObserver()
    private var windowChangeObservationTask: Task<Void, Error>?
    private var activeApplicationMonitorTask: Task<Void, Error>?
    private var sourceEditorMonitorTask: Task<Void, Error>?
    private var currentFileURL: URL?
    private var colorScheme: ColorScheme = .light

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
                            self.observeXcodeWindowChangeIfNeeded(app)
                        }
                        await self.updateContentForActiveEditor()
                        self.updateWindowLocation()
                    } else {
                        if ActiveApplicationMonitor.activeApplication?.bundleIdentifier != Bundle
                            .main.bundleIdentifier
                        {
                            self.widgetWindow.alphaValue = 0
                            self.panelWindow.alphaValue = 0
                            self.tabWindow.alphaValue = 0
                            if !UserDefaults.shared.value(for: \.chatPanelInASeparateWindow) {
                                self.chatWindow.alphaValue = 0
                            }
                        }
                    }
                }
            }
        }

        Task { @MainActor in
            presentationModeChangeObserver.onChange = { [weak self] in
                guard let self else { return }
                self.updateWindowLocation()
            }

            UserDefaults.shared.addObserver(
                presentationModeChangeObserver,
                forKeyPath: UserDefaultPreferenceKeys().suggestionPresentationMode.key,
                options: .new,
                context: nil
            )
        }

        Task { @MainActor in
            detachChatPanelObserver.onChange = { [weak self] in
                guard let self else { return }
                self.updateWindowLocation(animated: true)
            }
            UserDefaults.shared.addObserver(
                detachChatPanelObserver,
                forKeyPath: UserDefaultPreferenceKeys().chatPanelInASeparateWindow.key,
                options: .new,
                context: nil
            )
        }

        Task { @MainActor in
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
                self.suggestionPanelViewModel.colorScheme = self.colorScheme
                self.chatWindowViewModel.colorScheme = self.colorScheme
                Task {
                    await self.updateContentForActiveEditor()
                }
            }

            updateColorScheme()
            colorSchemeChangeObserver.onChange = {
                updateColorScheme()
            }

            UserDefaults.shared.addObserver(
                colorSchemeChangeObserver,
                forKeyPath: UserDefaultPreferenceKeys().widgetColorScheme.key,
                options: .new,
                context: nil
            )

            UserDefaults.standard.addObserver(
                colorSchemeChangeObserver,
                forKeyPath: "AppleInterfaceStyle",
                options: .new,
                context: nil
            )
        }
    }
}

// MARK: - Handle Events

public extension SuggestionWidgetController {
    func suggestCode(fileURL: URL) {
        widgetViewModel.isProcessing = false
        Task {
            if let suggestion = await dataSource?.suggestionForFile(at: fileURL) {
                suggestionPanelViewModel.content = .suggestion(suggestion)
                chatWindowViewModel.isPanelDisplayed = true
                suggestionPanelViewModel.isPanelDisplayed = true
                panelWindow.orderFront(nil)
            }
        }
    }

    func discardSuggestion(fileURL: URL) {
        widgetViewModel.isProcessing = false
        Task {
            await updateContentForActiveEditor(fileURL: fileURL)
        }
    }

    func markAsProcessing(_ isProcessing: Bool) {
        widgetViewModel.isProcessing = isProcessing
    }

    func presentError(_ errorDescription: String) {
        suggestionPanelViewModel.content = .error(errorDescription)
        chatWindowViewModel.isPanelDisplayed = true
        suggestionPanelViewModel.isPanelDisplayed = true
        widgetViewModel.isProcessing = false
        panelWindow.orderFront(nil)
    }

    func presentChatRoom(fileURL: URL) {
        widgetViewModel.isProcessing = false
        Task {
            if let chat = await dataSource?.chatForFile(at: fileURL) {
                chatWindowViewModel.chat = chat
                chatWindowViewModel.isPanelDisplayed = true
                suggestionPanelViewModel.isPanelDisplayed = true
                suggestionPanelViewModel.chat = chat

                if UserDefaults.shared.value(for: \.chatPanelInASeparateWindow) {
                    self.updateWindowLocation()
                }

                Task { @MainActor in
                    // looks like we need a delay.
                    try await Task.sleep(nanoseconds: 150_000_000)
                    NSApplication.shared.activate(ignoringOtherApps: true)
                    panelWindow.orderFront(nil)
                }
            }
        }
    }

    func closeChatRoom(fileURL: URL) {
        widgetViewModel.isProcessing = false
        Task {
            await updateContentForActiveEditor(fileURL: fileURL)
        }
    }

    func presentPromptToCode(fileURL: URL) {
        widgetViewModel.isProcessing = false
        Task {
            if let provider = await dataSource?.promptToCodeForFile(at: fileURL) {
                suggestionPanelViewModel.content = .promptToCode(provider)
                chatWindowViewModel.isPanelDisplayed = true
                suggestionPanelViewModel.isPanelDisplayed = true

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
        widgetViewModel.isProcessing = false
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

                if UserDefaults.shared.value(for: \.forceOrderWidgetToFront)
                    || notification.name == kAXWindowMovedNotification
                {
                    // We need to bring them front when the app enters fullscreen.
                    widgetWindow.orderFront(nil)
                    tabWindow.orderFront(nil)
                    chatWindow.orderFront(nil)
                    panelWindow.orderFront(nil)
                }

                if [
                    kAXFocusedUIElementChangedNotification,
                    kAXApplicationActivatedNotification,
                ].contains(notification.name) {
                    sourceEditorMonitorTask?.cancel()
                    sourceEditorMonitorTask = nil
                    observeEditorChangeIfNeeded(app)

                    guard let fileURL = try? await Environment.fetchCurrentFileURL() else {
                        // if it's switching to a ui component that is not a text area.
                        if ActiveApplicationMonitor.activeApplication?.isXcode ?? false {
                            suggestionPanelViewModel.content = nil
                            suggestionPanelViewModel.chat = nil
                        }
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
                        guard ActiveApplicationMonitor.activeXcode != nil else { return }
                        try Task.checkCancellation()
                        self.updateWindowLocation(animated: false)
                    }
                } else {
                    for await _ in merge(selectionRangeChange, scroll) {
                        guard let self else { return }
                        guard ActiveApplicationMonitor.activeXcode != nil else { return }
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
        guard UserDefaults.shared.value(for: \.suggestionPresentationMode) == .floatingWidget
        else {
            panelWindow.alphaValue = 0
            widgetWindow.alphaValue = 0
            tabWindow.alphaValue = 0
            chatWindow.alphaValue = 0
            return
        }

        let detachChat = UserDefaults.shared.value(for: \.chatPanelInASeparateWindow)

        if let widgetFrames = {
            if let xcode = ActiveApplicationMonitor.latestXcode {
                let application = AXUIElementCreateApplication(xcode.processIdentifier)
                if let focusElement = application.focusedElement,
                   focusElement.description == "Source Editor",
                   let parent = focusElement.parent,
                   let frame = parent.rect,
                   let screen = NSScreen.screens.first(where: { $0.frame.origin == .zero }),
                   let firstScreen = NSScreen.main
                {
                    let mode = UserDefaults.shared.value(for: \.suggestionWidgetPositionMode)
                    switch mode {
                    case .fixedToBottom:
                        return UpdateLocationStrategy.FixedToBottom().framesForWindows(
                            editorFrame: frame,
                            mainScreen: screen,
                            activeScreen: firstScreen
                        )
                    case .alignToTextCursor:
                        return UpdateLocationStrategy.AlignToTextCursor().framesForWindows(
                            editorFrame: frame,
                            mainScreen: screen,
                            activeScreen: firstScreen,
                            editor: focusElement
                        )
                    }
                } else if let window = application.focusedWindow,
                          !["open_quickly"].contains(window.identifier),
                          var frame = application.focusedWindow?.rect,
                          frame.size.height > 200,
                          let screen = NSScreen.screens.first(where: { $0.frame.origin == .zero }),
                          let firstScreen = NSScreen.main
                {
                    if ["Xcode.WorkspaceWindow"].contains(window.identifier) {
                        frame.size.height -= 40
                    }
                    
                    return UpdateLocationStrategy.FixedToBottom().framesForWindows(
                        editorFrame: frame,
                        mainScreen: screen,
                        activeScreen: firstScreen,
                        preferredInsideEditorMinWidth: 9_999_999_999
                    )
                }
            }
            return nil
        }() {
            widgetWindow.setFrame(widgetFrames.widgetFrame, display: false, animate: animated)
            panelWindow.setFrame(widgetFrames.panelFrame, display: false, animate: animated)
            tabWindow.setFrame(widgetFrames.tabFrame, display: false, animate: animated)
            suggestionPanelViewModel.alignTopToAnchor = widgetFrames.alignPanelTopToAnchor
            if detachChat {
                if chatWindow.alphaValue == 0 {
                    chatWindow.setFrame(panelWindow.frame, display: false, animate: false)
                }
            } else {
                chatWindow.setFrame(panelWindow.frame, display: false, animate: false)
            }
        }

        if let app = ActiveApplicationMonitor.activeApplication, app.isXcode {
            let application = AXUIElementCreateApplication(app.processIdentifier)
            let noFocus = application.focusedWindow == nil
            panelWindow.alphaValue = noFocus ? 0 : 1
            widgetWindow.alphaValue = noFocus ? 0 : 1
            tabWindow.alphaValue = noFocus ? 0 : 1

            if detachChat {
                chatWindow.alphaValue = chatWindowViewModel.chat != nil ? 1 : 0
            } else {
                chatWindow.alphaValue = noFocus ? 0 : 1
            }
        } else {
            panelWindow.alphaValue = 0
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
            suggestionPanelViewModel.content = nil
            chatWindowViewModel.chat = nil
            suggestionPanelViewModel.chat = nil
            return
        }

        if let chat = await dataSource?.chatForFile(at: fileURL) {
            if suggestionPanelViewModel.chat?.id != chat.id {
                suggestionPanelViewModel.chat = chat
            }
            if chatWindowViewModel.chat?.id != chat.id {
                chatWindowViewModel.chat = chat
            }
        } else {
            suggestionPanelViewModel.chat = nil
            chatWindowViewModel.chat = nil
        }

        if let provider = await dataSource?.promptToCodeForFile(at: fileURL) {
            suggestionPanelViewModel.content = .promptToCode(provider)
        } else if let suggestion = await dataSource?.suggestionForFile(at: fileURL) {
            suggestionPanelViewModel.content = .suggestion(suggestion)
        } else {
            suggestionPanelViewModel.content = nil
        }
    }
}

extension SuggestionWidgetController: NSWindowDelegate {
    public func windowWillMove(_ notification: Notification) {
        guard (notification.object as? NSWindow) === chatWindow else { return }
        Task { @MainActor in
            await Task.yield()
            UserDefaults.shared.set(true, for: \.chatPanelInASeparateWindow)
        }
    }

    public func windowDidBecomeKey(_ notification: Notification) {
        guard (notification.object as? NSWindow) === chatWindow else { return }
        let screenFrame = NSScreen.screens.first(where: { $0.frame.origin == .zero })?
            .frame ?? .zero
        var mouseLocation = NSEvent.mouseLocation
        let windowFrame = chatWindow.frame
        if mouseLocation.y > windowFrame.maxY - 40 {
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
        if currentLocation.y > windowFrame.size.height - 40 {
            performDrag(with: event)
        }
    }
}
