import ActiveApplicationMonitor
import AppKit
import AXNotificationStream
import DisplayLink
import SwiftUI

@MainActor
final class SuggestionPanelController {
    private lazy var window = {
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
            rootView: SuggestionPanelView(viewModel: viewModel)
                .allowsHitTesting(false)
                .frame(width: 400, height: 250)
        )
        it.setIsVisible(true)
        return it
    }()

    let viewModel = SuggestionPanelViewModel()

    private var windowChangeObservationTask: Task<Void, Error>?
    private var activeApplicationMonitorTask: Task<Void, Error>?
    private var activeApplication: NSRunningApplication? {
        ActiveApplicationMonitor.activeApplication
    }

    nonisolated init() {
        Task { @MainActor in
            activeApplicationMonitorTask = Task { [weak self] in
                guard let self else { return }
                var previousApp: NSRunningApplication?
                for await app in ActiveApplicationMonitor.createStream() {
                    try Task.checkCancellation()
                    defer { previousApp = app }
                    if let app, app.bundleIdentifier == "com.apple.dt.Xcode" {
                        if app != previousApp {
                            windowChangeObservationTask?.cancel()
                            windowChangeObservationTask = nil
                            self.observeXcodeWindowChangeIfNeeded()
                        }
                    }

                    self.updateWindowLocation()
                }
            }
        }
    }

    private func observeXcodeWindowChangeIfNeeded() {
        guard windowChangeObservationTask == nil else { return }
        windowChangeObservationTask = Task { [weak self] in
            guard let self else { return }
            let notifications = AXNotificationStream(
                app: activeApplication!,
                notificationNames: kAXMovedNotification
            )
            for await _ in notifications {
                try Task.checkCancellation()
                self.updateWindowLocation()
            }
        }
    }

    /// Update the window location.
    ///
    /// - note: It's possible to get the scroll view's postion by getting position on the focus
    /// element.
    private func updateWindowLocation() {
        if let activeXcode = activeApplication,
           activeXcode.bundleIdentifier == "com.apple.dt.Xcode"
        {
            let application = AXUIElementCreateApplication(activeXcode.processIdentifier)
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
                var frame = CGRect(origin: position, size: size)
                if foundSize, foundPosition, let screen {
                    frame.origin = .init(
                        x: frame.maxX + 2,
                        y: screen.frame.height - frame.minY - 250
                    )
                    frame.size = .init(width: 400, height: 300)
                    window.alphaValue = 1
                    window.setFrame(frame, display: false)
                    return
                }
            }
        }

        window.alphaValue = 0
    }
}

#warning("MUSTDO: Update when editing file is changed.")

@MainActor
final class SuggestionPanelViewModel: ObservableObject {
    @Published var startLineIndex: Int = 0
    @Published var suggestion: [String] = ["Hello", "World"] {
        didSet {
            isPanelDisplayed = !suggestion.isEmpty
        }
    }

    @Published var isPanelDisplayed = true

    func suggestCode(_ code: String, startLineIndex: Int) {
        suggestion = code.split(separator: "\n").map(String.init)
        self.startLineIndex = startLineIndex
    }
}

struct SuggestionPanelView: View {
    @ObservedObject var viewModel: SuggestionPanelViewModel

    var body: some View {
        if viewModel.isPanelDisplayed {
            if !viewModel.suggestion.isEmpty {
                ZStack(alignment: .topLeading) {
                    Color(red: 31 / 255, green: 31 / 255, blue: 36 / 255)
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
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Color(red: 31 / 255, green: 31 / 255, blue: 36 / 255)
            }
        } else {
            EmptyView()
        }
    }
}
