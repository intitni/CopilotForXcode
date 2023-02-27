import ActiveApplicationMonitor
import AppKit
import AXNotificationStream
import DisplayLink
import SwiftUI

@MainActor
final class SuggestionPanelController {
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
        it.contentView = NSHostingView(
            rootView: SuggestionPanelView(viewModel: suggestionPanelViewModel)
        )
        it.setIsVisible(true)
        return it
    }()

    let widgetViewModel = WidgetViewModel()
    let suggestionPanelViewModel = SuggestionPanelViewModel()

    private var windowChangeObservationTask: Task<Void, Error>?
    private var activeApplicationMonitorTask: Task<Void, Error>?
    private var xcode: NSRunningApplication?
    private var suggestionForFiles: [URL: Suggestion] = [:]

    enum Suggestion {
        case code([String], startLineIndex: Int)
    }

    nonisolated init() {
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
                    }

                    self.updateWindowLocation()
                }
            }
        }
    }

    func suggestCode(_ code: String, startLineIndex: Int, fileURL: URL) {
        suggestionPanelViewModel.suggestion = code.split(separator: "\n").map(String.init)
        suggestionPanelViewModel.startLineIndex = startLineIndex
        suggestionPanelViewModel.isPanelDisplayed = true
        suggestionForFiles[fileURL] = .code(
            suggestionPanelViewModel.suggestion,
            startLineIndex: startLineIndex
        )
    }

    func discardSuggestion(fileURL: URL) {
        suggestionForFiles[fileURL] = nil
        suggestionPanelViewModel.suggestion = []
        suggestionPanelViewModel.startLineIndex = 0
        suggestionPanelViewModel.isPanelDisplayed = false
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
                    case let .code(code, startLineIndex):
                        return
                            suggestionPanelViewModel.suggestion = code
                        suggestionPanelViewModel.startLineIndex = startLineIndex
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
                        x: frame.maxX - 4 - 30,
                        y: screen.frame.height - frame.minY - 30,
                        width: 30,
                        height: 30
                    )
                    widgetWindow.setFrame(anchorFrame, display: false)

                    let panelFrame = CGRect(
                        x: anchorFrame.maxX + 8,
                        y: anchorFrame.minY - 300 + 30,
                        width: 400,
                        height: 300
                    )
                    panelWindow.alphaValue = 1
                    panelWindow.setFrame(panelFrame, display: false)
                    return
                }
            }
        }

        panelWindow.alphaValue = 0
    }
}

@MainActor
final class SuggestionPanelViewModel: ObservableObject {
    @Published var startLineIndex: Int = 0
    @Published var suggestion: [String] = ["Hello", "World"]
    @Published var isPanelDisplayed = true
}

struct SuggestionPanelView: View {
    @ObservedObject var viewModel: SuggestionPanelViewModel
    @State var isHovered: Bool = false

    var body: some View {
        if !viewModel.suggestion.isEmpty {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(red: 31 / 255, green: 31 / 255, blue: 36 / 255))
                ScrollView {
                    VStack(alignment: .leading) {
                        ForEach(0..<viewModel.suggestion.count, id: \.self) { index in
                            HStack(alignment: .firstTextBaseline) {
                                Text("\(index)")
                                Text(viewModel.suggestion[index])
                            }
                        }
                        Spacer()
                    }
                    .foregroundColor(.white)
                    .font(.system(size: 12, design: .monospaced))
                    .multilineTextAlignment(.leading)
                    .padding()
                }
            }
            .opacity({
                guard viewModel.isPanelDisplayed else { return 0 }
                return isHovered ? 0.3 : 1
            }())
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onHover { yes in
                withAnimation(.easeInOut(duration: 0.2)) {
                    isHovered = yes
                }
            }
            .allowsHitTesting(viewModel.isPanelDisplayed)
        }
    }
}

@MainActor
final class WidgetViewModel: ObservableObject {
    enum Position {
        case topLeft
        case topRight
        case bottomLeft
        case bottomRight
    }

    var position: Position = .topRight

    init() {}
}

struct WidgetView: View {
    @ObservedObject var viewModel: WidgetViewModel
    var panelViewModel: SuggestionPanelViewModel

    var body: some View {
        Circle().fill(.blue)
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.2)) {
                    panelViewModel.isPanelDisplayed.toggle()
                }
            }
    }
}
