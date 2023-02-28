import AppKit
import DisplayLink
import Environment
import QuartzCore
import SwiftUI
import XPCShared

/// Present a tiny dot next to mouse cursor if real-time suggestion is enabled.
final class RealtimeSuggestionIndicatorController {
    class IndicatorContentViewModel: ObservableObject {
        @Published var isPrefetching = false
        private var prefetchTask: Task<Void, Error>?

        @MainActor
        func prefetch() {
            prefetchTask?.cancel()
            withAnimation(.easeIn(duration: 0.2)) {
                isPrefetching = true
            }
            prefetchTask = Task {
                try await Task.sleep(nanoseconds: 2 * 1_000_000_000)
                withAnimation(.easeOut(duration: 0.2)) {
                    isPrefetching = false
                }
            }
        }
    }

    struct IndicatorContentView: View {
        @ObservedObject var viewModel: IndicatorContentViewModel
        @State var progress: CGFloat = 1
        var opacityA: CGFloat { min(progress, 0.7) }
        var opacityB: CGFloat { 1 - progress }
        var scaleA: CGFloat { progress / 2 + 0.5 }
        var scaleB: CGFloat { max(1 - progress, 0.01) }

        var body: some View {
            Circle()
                .fill(Color.accentColor.opacity(opacityA))
                .scaleEffect(.init(width: scaleA, height: scaleA))
                .frame(width: 8, height: 8)
                .background(
                    Circle()
                        .fill(Color.white.opacity(viewModel.isPrefetching ? opacityB : 0))
                        .scaleEffect(.init(width: scaleB, height: scaleB))
                        .frame(width: 8, height: 8)
                )
        }
    }

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

    private let viewModel = IndicatorContentViewModel()
    private var userDefaultsObserver = UserDefaultsObserver()
    var isObserving = false {
        didSet {
            Task {
                await updateIndicatorVisibility()
            }
        }
    }

    private var displayLinkTask: Task<Void, Never>?

    @MainActor
    lazy var window = {
        let it = NSWindow(
            contentRect: .zero,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        it.isReleasedWhenClosed = false
        it.isOpaque = false
        it.backgroundColor = .white.withAlphaComponent(0)
        it.level = .statusBar
        it.contentView = NSHostingView(
            rootView: IndicatorContentView(viewModel: self.viewModel)
                .frame(minWidth: 10, minHeight: 10)
        )
        return it
    }()

    init() {
        Task {
            let sequence = NSWorkspace.shared.notificationCenter
                .notifications(named: NSWorkspace.didActivateApplicationNotification)
            for await notification in sequence {
                guard let app = notification
                    .userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
                else { continue }
                guard app.bundleIdentifier == "com.apple.dt.Xcode" else { continue }
                await updateIndicatorVisibility()
            }
        }

        Task {
            let sequence = NSWorkspace.shared.notificationCenter
                .notifications(named: NSWorkspace.didDeactivateApplicationNotification)
            for await notification in sequence {
                guard let app = notification
                    .userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
                else { continue }
                guard app.bundleIdentifier == "com.apple.dt.Xcode" else { continue }
                await updateIndicatorVisibility()
            }
        }

        Task {
            userDefaultsObserver.onChange = { [weak self] in
                Task { [weak self] in
                    await self?.updateIndicatorVisibility()
                }
            }
            UserDefaults.shared.addObserver(
                userDefaultsObserver,
                forKeyPath: SettingsKey.realtimeSuggestionToggle,
                options: .new,
                context: nil
            )
        }
    }

    private func updateIndicatorVisibility() async {
        let isVisible = await {
            let isOn = UserDefaults.shared.bool(forKey: SettingsKey.realtimeSuggestionToggle)
            let isXcodeActive = await Environment.isXcodeActive()
            return isOn && isXcodeActive && isObserving
        }()

        await { @MainActor in
            guard window.isVisible != isVisible else { return }
            if isVisible {
                if displayLinkTask == nil {
                    displayLinkTask = Task {
                        for await _ in DisplayLink.createStream() {
                            self.updateIndicatorLocation()
                        }
                    }
                }
            } else {
                displayLinkTask?.cancel()
                displayLinkTask = nil
            }
            window.setIsVisible(isVisible)
        }()
    }

    private func updateIndicatorLocation() {
        Task { @MainActor in
            if !window.isVisible {
                return
            }

            if let activeXcode = NSRunningApplication
                .runningApplications(withBundleIdentifier: "com.apple.dt.Xcode")
                .first(where: \.isActive)
            {
                let application = AXUIElementCreateApplication(activeXcode.processIdentifier)
                if let focusElement: AXUIElement = try? application
                    .copyValue(key: kAXFocusedUIElementAttribute),
                    let selectedRange: AXValue = try? focusElement
                    .copyValue(key: kAXSelectedTextRangeAttribute),
                    let rect: AXValue = try? focusElement.copyParameterizedValue(
                        key: kAXBoundsForRangeParameterizedAttribute,
                        parameters: selectedRange
                    )
                {
                    var frame: CGRect = .zero
                    let found = AXValueGetValue(rect, .cgRect, &frame)
                    let screen = NSScreen.screens.first
                    if found, let screen {
                        frame.origin = .init(
                            x: frame.maxX + 2,
                            y: screen.frame.height - frame.minY - 4
                        )
                        frame.size = .init(width: 10, height: 10)
                        window.alphaValue = 1
                        window.setFrame(frame, display: false, animate: true)
                        return
                    }
                }
            }

            window.alphaValue = 0
        }
    }

    func triggerPrefetchAnimation() {
        Task { @MainActor in
            viewModel.prefetch()
        }
    }
}
