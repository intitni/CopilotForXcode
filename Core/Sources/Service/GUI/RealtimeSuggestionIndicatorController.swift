import ActiveApplicationMonitor
import AppKit
import AsyncAlgorithms
import AXNotificationStream
import DisplayLink
import Environment
import Preferences
import QuartzCore
import SwiftUI
import UserDefaultsObserver

/// Deprecated: This class is no longer in use.
@available(*, deprecated, message: "This class is no longer in use.")
@MainActor
final class RealtimeSuggestionIndicatorController {
    class IndicatorContentViewModel: ObservableObject {
        @Published var isPrefetching = false
        @Published var progress: Double = 1
        private var prefetchTask: Task<Void, Error>?

        @MainActor
        func prefetch() {
            prefetchTask?.cancel()
            withAnimation(.easeIn(duration: 0.2)) {
                isPrefetching = true
            }
            prefetchTask = Task {
                try await Task.sleep(nanoseconds: 5 * 1_000_000_000)
                if isPrefetching {
                    endPrefetch()
                }
            }
        }

        @MainActor
        func endPrefetch() {
            withAnimation(.easeOut(duration: 0.2)) {
                isPrefetching = false
            }
        }
    }

    struct IndicatorContentView: View {
        @ObservedObject var viewModel: IndicatorContentViewModel
        var opacityA: CGFloat { min(viewModel.progress, 0.7) }
        var opacityB: CGFloat { 1 - viewModel.progress }
        var scaleA: CGFloat { viewModel.progress / 2 + 0.5 }
        var scaleB: CGFloat { max(1 - viewModel.progress, 0.01) }

        var body: some View {
            Circle()
                .fill(Color.accentColor.opacity(opacityA))
                .opacity(0.7)
                .scaleEffect(.init(width: scaleA, height: scaleA))
                .frame(width: 8, height: 8)
                .overlay {
                    if viewModel.isPrefetching {
                        Circle()
                            .fill(Color.white.opacity(opacityB))
                            .scaleEffect(.init(width: scaleB, height: scaleB))
                            .frame(width: 8, height: 8)
                            .onAppear {
                                Task {
                                    await Task.yield()
                                    withAnimation(
                                        .easeInOut(duration: 0.4)
                                            .repeatForever(
                                                autoreverses: true
                                            )
                                    ) {
                                        viewModel.progress = 0
                                    }
                                }
                            }.onDisappear {
                                withAnimation(.default) {
                                    viewModel.progress = 1
                                }
                            }
                    }
                }
        }
    }

    private let viewModel = IndicatorContentViewModel()
    private var userDefaultsObserver = UserDefaultsObserver(
        object: UserDefaults.shared,
        forKeyPaths: [UserDefaultPreferenceKeys().realtimeSuggestionToggle.key],
        context: nil
    )
    private var windowChangeObservationTask: Task<Void, Error>?
    private var activeApplicationMonitorTask: Task<Void, Error>?
    private var editorObservationTask: Task<Void, Error>?
    var isObserving = false {
        didSet {
            Task {
                await updateIndicatorVisibility()
            }
        }
    }

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
        it.level = .floating
        it.contentView = NSHostingView(
            rootView: IndicatorContentView(viewModel: self.viewModel)
                .frame(minWidth: 10, minHeight: 10)
        )
        return it
    }()

    nonisolated init() {
        if ProcessInfo.processInfo.environment["IS_UNIT_TEST"] == "YES" { return }

        Task { @MainActor in
            observeEditorChangeIfNeeded()
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
                        await self.updateIndicatorVisibility()
                        self.updateIndicatorLocation()
                    } else {
                        await self.updateIndicatorVisibility()
                    }
                }
            }
        }

        Task { @MainActor in
            userDefaultsObserver.onChange = { [weak self] in
                Task { @MainActor [weak self] in
                    await self?.updateIndicatorVisibility()
                    self?.updateIndicatorLocation()
                }
            }
        }
    }

    private func observeXcodeWindowChangeIfNeeded(_ app: NSRunningApplication) {
        guard windowChangeObservationTask == nil else { return }
        windowChangeObservationTask = Task { [weak self] in
            let notifications = AXNotificationStream(
                app: app,
                notificationNames:
                kAXMovedNotification,
                kAXResizedNotification,
                kAXFocusedWindowChangedNotification,
                kAXFocusedUIElementChangedNotification
            )
            self?.observeEditorChangeIfNeeded()
            for await notification in notifications {
                guard let self else { return }
                try Task.checkCancellation()
                self.updateIndicatorLocation()

                switch notification.name {
                case kAXFocusedUIElementChangedNotification, kAXFocusedWindowChangedNotification:
                    self.editorObservationTask?.cancel()
                    self.editorObservationTask = nil
                    self.observeEditorChangeIfNeeded()
                default:
                    continue
                }
            }
        }
    }

    private func observeEditorChangeIfNeeded() {
        guard editorObservationTask == nil,
              let activeXcode = ActiveApplicationMonitor.activeXcode
        else { return }
        let application = AXUIElementCreateApplication(activeXcode.processIdentifier)
        guard let focusElement: AXUIElement = try? application
            .copyValue(key: kAXFocusedUIElementAttribute),
            let focusElementType: String = try? focusElement
            .copyValue(key: kAXDescriptionAttribute),
            focusElementType == "Source Editor",
            let scrollView: AXUIElement = try? focusElement
            .copyValue(key: kAXParentAttribute),
            let scrollBar: AXUIElement = try? scrollView
            .copyValue(key: kAXVerticalScrollBarAttribute)
        else { return }

        updateIndicatorLocation()
        editorObservationTask = Task { [weak self] in
            let notificationsFromEditor = AXNotificationStream(
                app: activeXcode,
                element: focusElement,
                notificationNames:
                kAXResizedNotification,
                kAXMovedNotification,
                kAXLayoutChangedNotification,
                kAXSelectedTextChangedNotification
            )

            let notificationsFromScrollBar = AXNotificationStream(
                app: activeXcode,
                element: scrollBar,
                notificationNames: kAXValueChangedNotification
            )

            for await _ in merge(notificationsFromEditor, notificationsFromScrollBar) {
                guard let self else { return }
                try Task.checkCancellation()
                self.updateIndicatorLocation()
            }
        }
    }

    private func updateIndicatorVisibility() async {
        let isVisible = await {
            let isOn = UserDefaults.shared.value(for: \.realtimeSuggestionToggle)
            let isXcodeActive = await Environment.isXcodeActive()
            return isOn && isXcodeActive
        }()

        guard window.isVisible != isVisible else { return }
        window.setIsVisible(isVisible)
    }

    private func updateIndicatorLocation() {
        if !window.isVisible {
            return
        }

        if let activeXcode = ActiveApplicationMonitor.activeXcode {
            let application = AXUIElementCreateApplication(activeXcode.processIdentifier)
            if let focusElement: AXUIElement = try? application
                .copyValue(key: kAXFocusedUIElementAttribute),
                let focusElementType: String = try? focusElement
                .copyValue(key: kAXDescriptionAttribute),
                focusElementType == "Source Editor",
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
                    window.setFrame(frame, display: true)
                    window.orderFront(nil)
                    return
                }
            }
        }

        window.alphaValue = 0
    }

    func triggerPrefetchAnimation() {
        viewModel.prefetch()
    }

    func endPrefetchAnimation() {
        viewModel.endPrefetch()
    }
}

