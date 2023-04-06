import ActiveApplicationMonitor
import AppKit
import AsyncAlgorithms
import AXNotificationStream
import Environment
import Preferences
import SwiftUI

@MainActor
public final class SuggestionWidgetController {
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
        let it = NSWindow(
            contentRect: .zero,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        it.isReleasedWhenClosed = false
        it.isOpaque = false
        it.backgroundColor = .clear
        it.level = .floating
        it.hasShadow = true
        it.contentView = NSHostingView(
            rootView: WidgetView(
                viewModel: widgetViewModel,
                panelViewModel: suggestionPanelViewModel
            )
        )
        it.setIsVisible(true)
        return it
    }()

    private lazy var tabWindow = {
        let it = NSWindow(
            contentRect: .zero,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        it.isReleasedWhenClosed = false
        it.isOpaque = false
        it.backgroundColor = .clear
        it.level = .floating
        it.hasShadow = true
        it.contentView = NSHostingView(
            rootView: TabView(panelViewModel: suggestionPanelViewModel)
        )
        it.setIsVisible(true)
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
        it.level = .floating
        it.hasShadow = true
        it.contentView = NSHostingView(
            rootView: SuggestionPanelView(viewModel: suggestionPanelViewModel)
        )
        it.setIsVisible(true)
        it.canBecomeKeyChecker = { [suggestionPanelViewModel] in
            if case .chat = suggestionPanelViewModel.activeTab { return true }
            return false
        }
        return it
    }()

    let widgetViewModel = WidgetViewModel()
    let suggestionPanelViewModel = SuggestionPanelViewModel()

    private var presentationModeChangeObserver = UserDefaultsObserver()
    private var colorSchemeChangeObserver = UserDefaultsObserver()
    private var windowChangeObservationTask: Task<Void, Error>?
    private var activeApplicationMonitorTask: Task<Void, Error>?
    private var sourceEditorMonitorTask: Task<Void, Error>?
    private var currentFileURL: URL?
    private var colorScheme: ColorScheme = .light

    public var dataSource: SuggestionWidgetDataSource?
   
    public nonisolated init() {
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
                        self.updateWindowLocation()
                    } else {
                        if ActiveApplicationMonitor.activeApplication?.bundleIdentifier != Bundle
                            .main.bundleIdentifier
                        {
                            self.widgetWindow.alphaValue = 0
                            self.panelWindow.alphaValue = 0
                            self.tabWindow.alphaValue = 0
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

        Task { @MainActor in
            var switchTask: Task<Void, Error>?
            suggestionPanelViewModel.onActiveTabChanged = { activeTab in
                #warning("""
                TODO: There should be a better way for that
                Currently, we have to make the app an accessory so that we can type things in the chat mode.
                But in other modes, we want to keep it prohibited so the helper app won't take over the focus.
                """)
                switch activeTab {
                case .suggestion:
                    guard NSApp.activationPolicy() != .prohibited else { return }
                    switchTask?.cancel()
                    switchTask = Task {
                        try await Environment.makeXcodeActive()
                        try Task.checkCancellation()
                        NSApp.setActivationPolicy(.prohibited)
                    }
                case .chat:
                    guard NSApp.activationPolicy() != .accessory else { return }
                    switchTask?.cancel()
                    NSApp.setActivationPolicy(.accessory)
                }
            }
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
        widgetViewModel.isProcessing = false
    }

    func presentChatRoom(fileURL: URL) {
        widgetViewModel.isProcessing = false
        Task {
            if let chat = await dataSource?.chatForFile(at: fileURL) {
                suggestionPanelViewModel.chat = chat
                
                Task { @MainActor in
                    // looks like we need a delay.
                    try await Task.sleep(nanoseconds: 150_000_000)
                    NSApplication.shared.activate(ignoringOtherApps: true)
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
                kAXMovedNotification,
                kAXResizedNotification,
                kAXMainWindowChangedNotification,
                kAXFocusedWindowChangedNotification,
                kAXFocusedUIElementChangedNotification,
                kAXWindowMovedNotification,
                kAXWindowResizedNotification
            )
            for await notification in notifications {
                guard let self else { return }
                try Task.checkCancellation()
                self.updateWindowLocation(animated: false)
                panelWindow.orderFront(nil)
                widgetWindow.orderFront(nil)
                tabWindow.orderFront(nil)

                if notification.name == kAXFocusedUIElementChangedNotification {
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
        func hide() {
            panelWindow.alphaValue = 0
            widgetWindow.alphaValue = 0
            tabWindow.alphaValue = 0
        }

        guard UserDefaults.shared.value(for: \.suggestionPresentationMode) == .floatingWidget
        else {
            hide()
            return
        }

        if let xcode = ActiveApplicationMonitor.activeXcode {
            let application = AXUIElementCreateApplication(xcode.processIdentifier)
            if let focusElement = application.focusedElement,
               focusElement.description == "Source Editor",
               let parent = focusElement.parent,
               let frame = parent.rect,
               let screen = NSScreen.main,
               let firstScreen = NSScreen.screens.first
            {
                let mode = UserDefaults.shared.value(for: \.suggestionWidgetPositionMode)
                switch mode {
                case .fixedToBottom:
                    let result = UpdateLocationStrategy.FixedToBottom().framesForWindows(
                        editorFrame: frame,
                        mainScreen: screen,
                        activeScreen: firstScreen
                    )
                    widgetWindow.setFrame(result.widgetFrame, display: false, animate: animated)
                    panelWindow.setFrame(result.panelFrame, display: false, animate: animated)
                    tabWindow.setFrame(result.tabFrame, display: false, animate: animated)
                    suggestionPanelViewModel.alignTopToAnchor = result.alignPanelTopToAnchor
                case .alignToTextCursor:
                    let result = UpdateLocationStrategy.AlignToTextCursor().framesForWindows(
                        editorFrame: frame,
                        mainScreen: screen,
                        activeScreen: firstScreen,
                        editor: focusElement
                    )
                    widgetWindow.setFrame(result.widgetFrame, display: false, animate: animated)
                    panelWindow.setFrame(result.panelFrame, display: false, animate: animated)
                    tabWindow.setFrame(result.tabFrame, display: false, animate: animated)
                    suggestionPanelViewModel.alignTopToAnchor = result.alignPanelTopToAnchor
                }

                panelWindow.alphaValue = 1
                widgetWindow.alphaValue = 1
                tabWindow.alphaValue = 1
                return
            }
        }

        hide()
    }

    private func updateContentForActiveEditor(fileURL: URL? = nil) async {
        guard let fileURL = await {
            if let fileURL { return fileURL }
            return try? await Environment.fetchCurrentFileURL()
        }() else {
            suggestionPanelViewModel.content = nil
            suggestionPanelViewModel.chat = nil
            return
        }

        if let suggestion = await dataSource?.suggestionForFile(at: fileURL) {
            suggestionPanelViewModel.content = .suggestion(suggestion)
        } else {
            suggestionPanelViewModel.content = nil
        }

        if let chat = await dataSource?.chatForFile(at: fileURL) {
            suggestionPanelViewModel.chat = chat
        } else {
            suggestionPanelViewModel.chat = nil
        }
    }
}

class CanBecomeKeyWindow: NSWindow {
    var canBecomeKeyChecker: () -> Bool = { true }
    override var canBecomeKey: Bool { canBecomeKeyChecker() }
    override var canBecomeMain: Bool { canBecomeKeyChecker() }
}
