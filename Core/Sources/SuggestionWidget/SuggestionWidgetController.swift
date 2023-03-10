import ActiveApplicationMonitor
import AppKit
import AsyncAlgorithms
import AXNotificationStream
import Environment
import Highlightr
import Splash
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

    private var userDefaultsObserver = UserDefaultsObserver()
    private var windowChangeObservationTask: Task<Void, Error>?
    private var activeApplicationMonitorTask: Task<Void, Error>?
    private var sourceEditorMonitorTask: Task<Void, Error>?
    private var suggestionForFiles: [URL: Suggestion] = [:]
    private var currentFileURL: URL?

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
        language: String,
        startLineIndex: Int,
        fileURL: URL,
        currentSuggestionIndex: Int,
        suggestionCount: Int
    ) {
        withAnimation(.easeInOut(duration: 0.2)) {
            if fileURL == currentFileURL || currentFileURL == nil {
                suggestionPanelViewModel.suggestion = highlighted(code: code, language: language)
                suggestionPanelViewModel.startLineIndex = startLineIndex
                suggestionPanelViewModel.isPanelDisplayed = true
                suggestionPanelViewModel.currentSuggestionIndex = currentSuggestionIndex
                suggestionPanelViewModel.suggestionCount = suggestionCount
            }
            suggestionForFiles[fileURL] = .code(
                code,
                language: language,
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
            if fileURL == currentFileURL || currentFileURL == nil {
                suggestionPanelViewModel.suggestion = []
                suggestionPanelViewModel.startLineIndex = 0
                suggestionPanelViewModel.currentSuggestionIndex = 0
                suggestionPanelViewModel.suggestionCount = 0
                suggestionPanelViewModel.isPanelDisplayed = false
            }
            widgetViewModel.isProcessing = false
        }
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

                if notification.name == kAXFocusedUIElementChangedNotification {
                    sourceEditorMonitorTask?.cancel()
                    sourceEditorMonitorTask = nil
                    observeEditorChangeIfNeeded(app)

                    guard let fileURL = try? await Environment.fetchCurrentFileURL() else {
                        suggestionPanelViewModel.suggestion = []
                        continue
                    }
                    currentFileURL = fileURL
                    guard let suggestion = suggestionForFiles[fileURL]
                    else {
                        suggestionPanelViewModel.suggestion = []
                        continue
                    }

                    switch suggestion {
                    case let .code(
                        code,
                        language,
                        startLineIndex,
                        currentSuggestionIndex,
                        suggestionCount
                    ):
                        suggestionPanelViewModel.suggestion = highlighted(
                            code: code,
                            language: language
                        )
                        suggestionPanelViewModel.startLineIndex = startLineIndex
                        suggestionPanelViewModel.currentSuggestionIndex = currentSuggestionIndex
                        suggestionPanelViewModel.suggestionCount = suggestionCount
                    }
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
                    for await _ in merge(selectionRangeChange, scroll)
                        .debounce(for: Duration.milliseconds(500))
                    {
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
    /// - note: It's possible to get the scroll view's postion by getting position on the focus
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

                panelWindow.orderFront(nil)
                widgetWindow.orderFront(nil)
                panelWindow.alphaValue = 1
                widgetWindow.alphaValue = 1
                return
            }
        }

        hide()
    }
}

func highlighted(code: String, language: String) -> [NSAttributedString] {
    switch language {
    case "swift":
        let plainTextColor = #colorLiteral(red: 0.6509803922, green: 0.6980392157, blue: 0.7529411765, alpha: 1)
        let highlighter =
            SyntaxHighlighter(
                format: AttributedStringOutputFormat(theme: .init(
                    font: .init(size: 14),
                    plainTextColor: plainTextColor,
                    tokenColors: [
                        .keyword: #colorLiteral(red: 0.8258609176, green: 0.5708742738, blue: 0.8922662139, alpha: 1),
                        .string: #colorLiteral(red: 0.6253595352, green: 0.7963448763, blue: 0.5427476764, alpha: 1),
                        .type: #colorLiteral(red: 0.9221783876, green: 0.7978314757, blue: 0.5575165749, alpha: 1),
                        .call: #colorLiteral(red: 0.4466812611, green: 0.742190659, blue: 0.9515134692, alpha: 1),
                        .number: #colorLiteral(red: 0.8620631099, green: 0.6468816996, blue: 0.4395158887, alpha: 1),
                        .comment: #colorLiteral(red: 0.4233166873, green: 0.4612616301, blue: 0.5093258619, alpha: 1),
                        .property: #colorLiteral(red: 0.906378448, green: 0.5044228435, blue: 0.5263597369, alpha: 1),
                        .dotAccess: #colorLiteral(red: 0.906378448, green: 0.5044228435, blue: 0.5263597369, alpha: 1),
                        .preprocessing: #colorLiteral(red: 0.3776347041, green: 0.8792117238, blue: 0.4709561467, alpha: 1),
                    ]
                ))
            )
        let formatted = NSMutableAttributedString(attributedString: highlighter.highlight(code))
        formatted.addAttributes(
            [.font: NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)],
            range: NSRange(location: 0, length: formatted.length)
        )
        return convertToCodeLines(formatted)
    default:
        guard let highlighter = Highlightr() else {
            return convertToCodeLines(NSAttributedString(string: code))
        }
        highlighter.setTheme(to: "atom-one-dark")
        highlighter.theme.setCodeFont(.monospacedSystemFont(ofSize: 13, weight: .regular))
        guard let formatted = highlighter.highlight(code, as: language) else {
            return convertToCodeLines(NSAttributedString(string: code))
        }
        return convertToCodeLines(formatted)
    }
}

private func convertToCodeLines(_ formatedCode: NSAttributedString) -> [NSAttributedString] {
    let input = formatedCode.string
    let separatedInput = input.components(separatedBy: "\n")
    var output = [NSAttributedString]()
    var start = 0
    for sub in separatedInput {
        let range = NSMakeRange(start, sub.utf16.count)
        let attributedString = formatedCode.attributedSubstring(from: range)
        let mutable = NSMutableAttributedString(attributedString: attributedString)
        // use regex to replace all spaces to a middle dot
        do {
            let regex = try NSRegularExpression(pattern: "[ ]*", options: [])
            let result = regex.matches(
                in: mutable.string,
                range: NSRange(location: 0, length: mutable.mutableString.length)
            )
            for r in result {
                let range = r.range
                mutable.replaceCharacters(
                    in: range,
                    with: String(repeating: "·", count: range.length)
                )
                mutable.addAttributes([
                    .foregroundColor: NSColor.white.withAlphaComponent(0.1),
                ], range: range)
            }
        } catch {}
        output.append(mutable)
        start += range.length + 1
    }
    return output
}

enum UpdateLocationStrategy {
    struct AlignToTextCursor {
        func framesForWindows(
            editorFrame: CGRect,
            mainScreen: NSScreen,
            activeScreen: NSScreen,
            editor: AXUIElement
        ) -> (widgetFrame: CGRect, panelFrame: CGRect, alignPanelTopToAnchor: Bool) {
            guard let selectedRange: AXValue = try? editor
                .copyValue(key: kAXSelectedTextRangeAttribute),
                let rect: AXValue = try? editor.copyParameterizedValue(
                    key: kAXBoundsForRangeParameterizedAttribute,
                    parameters: selectedRange
                )
            else {
                return FixedToBottom().framesForWindows(
                    editorFrame: editorFrame,
                    mainScreen: mainScreen,
                    activeScreen: activeScreen
                )
            }
            var frame: CGRect = .zero
            let found = AXValueGetValue(rect, .cgRect, &frame)
            guard found else {
                return FixedToBottom().framesForWindows(
                    editorFrame: editorFrame,
                    mainScreen: mainScreen,
                    activeScreen: activeScreen
                )
            }
            return HorizontalMovable().framesForWindows(
                y: activeScreen.frame.height - frame.maxY,
                alignPanelTopToAnchor: nil,
                editorFrame: editorFrame,
                mainScreen: mainScreen,
                activeScreen: activeScreen
            )
        }
    }

    struct FixedToBottom {
        func framesForWindows(
            editorFrame: CGRect,
            mainScreen: NSScreen,
            activeScreen: NSScreen
        ) -> (widgetFrame: CGRect, panelFrame: CGRect, alignPanelTopToAnchor: Bool) {
            return HorizontalMovable().framesForWindows(
                y: activeScreen.frame.height - editorFrame.maxY + Style.widgetPadding,
                alignPanelTopToAnchor: false,
                editorFrame: editorFrame,
                mainScreen: mainScreen,
                activeScreen: activeScreen
            )
        }
    }

    struct HorizontalMovable {
        func framesForWindows(
            y: CGFloat,
            alignPanelTopToAnchor fixedAlignment: Bool?,
            editorFrame: CGRect,
            mainScreen: NSScreen,
            activeScreen: NSScreen
        ) -> (widgetFrame: CGRect, panelFrame: CGRect, alignPanelTopToAnchor: Bool) {
            let maxY = max(
                y,
                activeScreen.frame.height - editorFrame.maxY + Style.widgetPadding,
                4 + mainScreen.frame.minY
            )
            let y = min(
                maxY,
                mainScreen.frame.maxY - 4,
                activeScreen.frame.height - editorFrame.minY - Style.widgetHeight - Style
                    .widgetPadding
            )

            let proposedAnchorFrameOnTheRightSide = CGRect(
                x: editorFrame.maxX - Style.widgetPadding - Style.widgetWidth,
                y: y,
                width: Style.widgetWidth,
                height: Style.widgetHeight
            )

            let proposedPanelX = proposedAnchorFrameOnTheRightSide.maxX + Style
                .widgetPadding * 2
            let putPanelToTheRight = mainScreen.frame.maxX > proposedPanelX + Style.panelWidth
            let alignPanelTopToAnchor = fixedAlignment ?? (y > activeScreen.frame.midY)

            if putPanelToTheRight {
                let anchorFrame = proposedAnchorFrameOnTheRightSide
                let panelFrame = CGRect(
                    x: proposedPanelX,
                    y: alignPanelTopToAnchor ? anchorFrame.maxY - Style.panelHeight : anchorFrame
                        .minY,
                    width: Style.panelWidth,
                    height: Style.panelHeight
                )
                return (anchorFrame, panelFrame, alignPanelTopToAnchor)
            } else {
                let proposedAnchorFrameOnTheLeftSide = CGRect(
                    x: editorFrame.minX + Style.widgetPadding,
                    y: proposedAnchorFrameOnTheRightSide.origin.y,
                    width: Style.widgetWidth,
                    height: Style.widgetHeight
                )
                let proposedPanelX = proposedAnchorFrameOnTheLeftSide.minX - Style
                    .widgetPadding * 2 - Style.panelWidth
                let putAnchorToTheLeft = proposedPanelX > mainScreen.frame.minX

                if putAnchorToTheLeft {
                    let anchorFrame = proposedAnchorFrameOnTheLeftSide
                    let panelFrame = CGRect(
                        x: proposedPanelX,
                        y: alignPanelTopToAnchor ? anchorFrame.maxY - Style
                            .panelHeight : anchorFrame
                            .minY,
                        width: Style.panelWidth,
                        height: Style.panelHeight
                    )
                    return (anchorFrame, panelFrame, alignPanelTopToAnchor)
                } else {
                    let anchorFrame = proposedAnchorFrameOnTheRightSide
                    let panelFrame = CGRect(
                        x: anchorFrame.maxX - Style.panelWidth,
                        y: alignPanelTopToAnchor ? anchorFrame.maxY - Style.panelHeight - Style
                            .widgetHeight - Style.widgetPadding : anchorFrame.maxY + Style
                            .widgetPadding,
                        width: Style.panelWidth,
                        height: Style.panelHeight
                    )
                    return (anchorFrame, panelFrame, alignPanelTopToAnchor)
                }
            }
        }
    }
}
