import ActiveApplicationMonitor
import AppKit
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
        it.level = .statusBar
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
        it.level = .statusBar
        it.hasShadow = true
        it.contentView = NSHostingView(
            rootView: SuggestionPanelView(viewModel: suggestionPanelViewModel)
        )
        it.setIsVisible(true)
        return it
    }()

    let widgetViewModel = WidgetViewModel()
    let suggestionPanelViewModel = SuggestionPanelViewModel()

    private var userDefaultsObserver = UserDefaultsObserver()
    private var windowChangeObservationTask: Task<Void, Error>?
    private var activeApplicationMonitorTask: Task<Void, Error>?
    private var xcode: NSRunningApplication?
    private var suggestionForFiles: [URL: Suggestion] = [:]

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
        case code([String], startLineIndex: Int, currentSuggestionIndex: Int, suggestionCount: Int)
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
            userDefaultsObserver.onChange = { [weak self] in
                guard let self else { return }
                self.updateWindowLocation()
            }
            UserDefaults.shared.addObserver(
                userDefaultsObserver,
                forKeyPath: SettingsKey.suggestionPresentationMode,
                options: .new,
                context: nil
            )
        }
    }

    public func suggestCode(
        _ code: String,
        startLineIndex: Int,
        fileURL: URL,
        currentSuggestionIndex: Int,
        suggestionCount: Int
    ) {
        withAnimation(.easeInOut(duration: 0.2)) {
            suggestionPanelViewModel.suggestion = code.split(separator: "\n").map(String.init)
            suggestionPanelViewModel.startLineIndex = startLineIndex
            suggestionPanelViewModel.isPanelDisplayed = true
            suggestionPanelViewModel.currentSuggestionIndex = currentSuggestionIndex
            suggestionPanelViewModel.suggestionCount = suggestionCount
            suggestionForFiles[fileURL] = .code(
                suggestionPanelViewModel.suggestion,
                startLineIndex: startLineIndex,
                currentSuggestionIndex: currentSuggestionIndex,
                suggestionCount: suggestionCount
            )
            widgetViewModel.isProcessing = false
        }
    }

    public func discardSuggestion(fileURL: URL) {
        withAnimation(.easeInOut(duration: 0.2)) {
            suggestionForFiles[fileURL] = nil
            suggestionPanelViewModel.suggestion = []
            suggestionPanelViewModel.startLineIndex = 0
            suggestionPanelViewModel.currentSuggestionIndex = 0
            suggestionPanelViewModel.suggestionCount = 0
            suggestionPanelViewModel.isPanelDisplayed = false
            widgetViewModel.isProcessing = false
        }
    }

    public func markAsProcessing(_ isProcessing: Bool) {
        widgetViewModel.isProcessing = isProcessing
    }

    private func observeXcodeWindowChangeIfNeeded(_ app: NSRunningApplication) {
        xcode = app
        guard windowChangeObservationTask == nil else { return }
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
                self.updateWindowLocation()

                if notification.name == kAXFocusedUIElementChangedNotification {
                    guard let fileURL = try? await Environment.fetchCurrentFileURL(),
                          let suggestion = suggestionForFiles[fileURL]
                    else {
                        suggestionPanelViewModel.suggestion = []
                        continue
                    }
                    switch suggestion {
                    case let .code(code, startLineIndex, currentSuggestionIndex, suggestionCount):
                        suggestionPanelViewModel.suggestion = code
                        suggestionPanelViewModel.startLineIndex = startLineIndex
                        suggestionPanelViewModel.currentSuggestionIndex = currentSuggestionIndex
                        suggestionPanelViewModel.suggestionCount = suggestionCount
                    }
                }
            }
        }
    }

    /// Update the window location.
    ///
    /// - note: It's possible to get the scroll view's postion by getting position on the focus
    /// element.
    private func updateWindowLocation() {
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

        if let xcode {
            let application = AXUIElementCreateApplication(xcode.processIdentifier)
            if let focusElement: AXUIElement = try? application
                .copyValue(key: kAXFocusedUIElementAttribute),
                let focusElementType: String = try? focusElement
                .copyValue(key: kAXDescriptionAttribute),
                focusElementType == "Source Editor",
                let parent: AXUIElement = try? focusElement.copyValue(key: kAXParentAttribute),
                let positionValue: AXValue = try? parent
                .copyValue(key: kAXPositionAttribute),
                let sizeValue: AXValue = try? parent
                .copyValue(key: kAXSizeAttribute)
            {
                var position: CGPoint = .zero
                let foundPosition = AXValueGetValue(positionValue, .cgPoint, &position)
                var size: CGSize = .zero
                let foundSize = AXValueGetValue(sizeValue, .cgSize, &size)
                let screen = NSScreen.screens.first
                let frame = CGRect(origin: position, size: size)
                if foundSize, foundPosition, let screen {
                    let anchorFrame = CGRect(
                        x: frame.maxX - 4 - Style.widgetWidth,
                        y: screen.frame.height - frame.minY - Style.widgetHeight - 4,
                        width: Style.widgetWidth,
                        height: Style.widgetHeight
                    )
                    widgetWindow.setFrame(anchorFrame, display: false)

                    let proposedPanelX = anchorFrame.maxX + 8
                    let putPanelToTheRight = screen.frame.maxX > proposedPanelX + Style.panelWidth

                    let panelFrame = CGRect(
                        x: putPanelToTheRight ? proposedPanelX : anchorFrame.maxX - Style
                            .panelWidth,
                        y: putPanelToTheRight ? anchorFrame.minY - Style.panelHeight + Style
                            .widgetHeight : anchorFrame.minY - Style.panelHeight - 4,
                        width: Style.panelWidth,
                        height: Style.panelHeight
                    )
                    panelWindow.setFrame(panelFrame, display: false)

                    panelWindow.alphaValue = 1
                    widgetWindow.alphaValue = 1
                    return
                }
            }
        }

        hide()
    }
}
