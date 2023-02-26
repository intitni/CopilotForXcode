import AppKit
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
        it.backgroundColor = .white
        it.level = .statusBar
        it.contentView = NSHostingView(
            rootView: SuggestionPanelView(viewModel: viewModel)
                .allowsHitTesting(false)
                .frame(width: 500, height: 300)
        )
        it.setIsVisible(true)
        return it
    }()

    private var displayLinkTask: Task<Void, Never>?
    private let viewModel = SuggestionPanelViewModel()

    nonisolated init() {
        Task { @MainActor in
            displayLinkTask = Task {
                for await _ in DisplayLink.createStream() {
                    self.updateWindowLocation()
                }
            }
        }
    }

    /// Update the window location
    ///
    /// - note:
    private func updateWindowLocation() {
        if let activeXcode = NSRunningApplication
            .runningApplications(withBundleIdentifier: "com.apple.dt.Xcode")
            .first(where: \.isActive)
        {
            let application = AXUIElementCreateApplication(activeXcode.processIdentifier)
            if let focusElement: AXUIElement = try? application
                .copyValue(key: kAXFocusedUIElementAttribute),
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
                        y: screen.frame.height - frame.minY - 300
                    )
                    frame.size = .init(width: 500, height: 300)
                    window.alphaValue = 1
                    window.setFrame(frame, display: false, animate: true)
                    return
                }
            }
        }

        window.alphaValue = 0
    }
}

final class SuggestionPanelViewModel: ObservableObject {
    @Published var suggetion: String = "Hello World"
}

struct SuggestionPanelView: View {
    @ObservedObject var viewModel: SuggestionPanelViewModel

    var body: some View {
        Text(viewModel.suggetion)
    }
}
