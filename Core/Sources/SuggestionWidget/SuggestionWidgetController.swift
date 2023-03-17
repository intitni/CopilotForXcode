import ActiveApplicationMonitor
import AppKit
import AsyncAlgorithms
import AXNotificationStream
import Environment
import SwiftUI
import XPCShared

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

    private lazy var panelWindow = {
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
            rootView: SuggestionPanelView(viewModel: suggestionPanelViewModel)
        )
        it.setIsVisible(true)
        return it
    }()

    let widgetViewModel = WidgetViewModel()
    let suggestionPanelViewModel = SuggestionPanelViewModel()

    private var presentationModeChangeObserver = UserDefaultsObserver()
    private var colorSchemeChangeObserver = UserDefaultsObserver()
    private var windowChangeObservationTask: Task<Void, Error>?
    private var activeApplicationMonitorTask: Task<Void, Error>?
    private var sourceEditorMonitorTask: Task<Void, Error>?
    private var suggestionForFiles: [URL: Suggestion] = [:]
    private var currentFileURL: URL?
    private var colorScheme: ColorScheme = .light

    public var onAcceptButtonTapped: (() -> Void)? {
        get { suggestionPanelViewModel.onAcceptButtonTapped }
        set { suggestionPanelViewModel.onAcceptButtonTapped = newValue }
    }

    public var onRejectButtonTapped: (() -> Void)? {
        get { suggestionPanelViewModel.onRejectButtonTapped }
        set { suggestionPanelViewModel.onRejectButtonTapped = newValue }
    }

    public var onPreviousButtonTapped: (() -> Void)? {
        get { suggestionPanelViewModel.onPreviousButtonTapped }
        set { suggestionPanelViewModel.onPreviousButtonTapped = newValue }
    }

    public var onNextButtonTapped: (() -> Void)? {
        get { suggestionPanelViewModel.onNextButtonTapped }
        set { suggestionPanelViewModel.onNextButtonTapped = newValue }
    }

    enum Suggestion {
        case code(
            String,
            language: String,
            startLineIndex: Int,
            currentSuggestionIndex: Int,
            suggestionCount: Int
        )
    }

    public nonisolated init() {
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
                        panelWindow.alphaValue = 0
                        widgetWindow.alphaValue = 0
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
                forKeyPath: SettingsKey.suggestionPresentationMode,
                options: .new,
                context: nil
            )
        }

        Task { @MainActor in
            let updateColorScheme = { @MainActor [weak self] in
                guard let self else { return }
                let widgetColorScheme = WidgetColorScheme(
                    rawValue: UserDefaults.shared
                        .integer(forKey: SettingsKey.widgetColorScheme)
                ) ?? .system
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
                    await self.updateSuggestionsForActiveEditor()
                }
            }

            updateColorScheme()
            colorSchemeChangeObserver.onChange = {
                updateColorScheme()
            }

            UserDefaults.shared.addObserver(
                colorSchemeChangeObserver,
                forKeyPath: SettingsKey.widgetColorScheme,
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

    public func suggestCode(
        _ code: String,
        language: String,
        startLineIndex: Int,
        fileURL: URL,
        currentSuggestionIndex: Int,
        suggestionCount: Int
    ) {
        if fileURL == currentFileURL || currentFileURL == nil {
            suggestionPanelViewModel.suggestion = .init(
                startLineIndex: startLineIndex,
                code: highlighted(
                    code: code,
                    language: language,
                    brightMode: colorScheme == .light
                ),
                suggestionCount: suggestionCount,
                currentSuggestionIndex: currentSuggestionIndex
            )

            suggestionPanelViewModel.isPanelDisplayed = true
        }

        widgetViewModel.isProcessing = false
        suggestionForFiles[fileURL] = .code(
            code,
            language: language,
            startLineIndex: startLineIndex,
            currentSuggestionIndex: currentSuggestionIndex,
            suggestionCount: suggestionCount
        )
    }

    public func discardSuggestion(fileURL: URL) {
        suggestionForFiles[fileURL] = nil
        if fileURL == currentFileURL || currentFileURL == nil {
            suggestionPanelViewModel.suggestion = .empty
            suggestionPanelViewModel.isPanelDisplayed = false
        }
        widgetViewModel.isProcessing = false
    }

    public func markAsProcessing(_ isProcessing: Bool) {
        widgetViewModel.isProcessing = isProcessing
    }

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
                kAXFocusedUIElementChangedNotification
            )
            for await notification in notifications {
                guard let self else { return }
                try Task.checkCancellation()
                self.updateWindowLocation(animated: false)
                panelWindow.orderFront(nil)
                widgetWindow.orderFront(nil)

                if notification.name == kAXFocusedUIElementChangedNotification {
                    sourceEditorMonitorTask?.cancel()
                    sourceEditorMonitorTask = nil
                    observeEditorChangeIfNeeded(app)

                    guard let fileURL = try? await Environment.fetchCurrentFileURL() else {
                        suggestionPanelViewModel.suggestion = .empty
                        continue
                    }
                    guard fileURL != currentFileURL else { continue }
                    currentFileURL = fileURL
                    await updateSuggestionsForActiveEditor(fileURL: fileURL)
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
                    element: scrollBar, notificationNames: kAXValueChangedNotification
                )

                if #available(macOS 13.0, *) {
                    for await _ in merge(
                        selectionRangeChange.debounce(for: Duration.milliseconds(500)),
                        scroll
                    ) {
                        guard let self else { return }
                        try Task.checkCancellation()
                        let mode = SuggestionWidgetPositionMode(
                            rawValue: UserDefaults.shared
                                .integer(forKey: SettingsKey.suggestionWidgetPositionMode)
                        )
                        if mode != .alignToTextCursor { break }
                        self.updateWindowLocation(animated: false)
                    }
                } else {
                    for await _ in merge(selectionRangeChange, scroll) {
                        guard let self else { return }
                        try Task.checkCancellation()
                        let mode = SuggestionWidgetPositionMode(
                            rawValue: UserDefaults.shared
                                .integer(forKey: SettingsKey.suggestionWidgetPositionMode)
                        )
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
        }

        guard PresentationMode(
            rawValue: UserDefaults.shared
                .integer(forKey: SettingsKey.suggestionPresentationMode)
        ) == .floatingWidget
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
                let mode = SuggestionWidgetPositionMode(
                    rawValue: UserDefaults.shared
                        .integer(forKey: SettingsKey.suggestionWidgetPositionMode)
                ) ?? .fixedToBottom
                switch mode {
                case .fixedToBottom:
                    let result = UpdateLocationStrategy.FixedToBottom().framesForWindows(
                        editorFrame: frame,
                        mainScreen: screen,
                        activeScreen: firstScreen
                    )
                    widgetWindow.setFrame(result.widgetFrame, display: false, animate: animated)
                    panelWindow.setFrame(result.panelFrame, display: false, animate: animated)
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
                    suggestionPanelViewModel.alignTopToAnchor = result.alignPanelTopToAnchor
                }

                panelWindow.alphaValue = 1
                widgetWindow.alphaValue = 1
                return
            }
        }

        hide()
    }

    private func updateSuggestionsForActiveEditor(fileURL: URL? = nil) async {
        guard let fileURL = await {
            if let fileURL { return fileURL }
            return try? await Environment.fetchCurrentFileURL()
        }(),
            let suggestion = suggestionForFiles[fileURL]
        else {
            suggestionPanelViewModel.suggestion = .empty
            return
        }

        switch suggestion {
        case let .code(
            code,
            language,
            startLineIndex,
            currentSuggestionIndex,
            suggestionCount
        ):
            suggestionPanelViewModel.suggestion = .init(
                startLineIndex: startLineIndex,
                code: highlighted(
                    code: code,
                    language: language,
                    brightMode: colorScheme == .light
                ),
                suggestionCount: suggestionCount,
                currentSuggestionIndex: currentSuggestionIndex
            )
        }
    }
}
