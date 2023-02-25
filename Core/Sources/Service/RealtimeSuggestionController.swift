import AppKit
import CGEventObserver
import Foundation
import os.log
import QuartzCore
import SwiftUI
import XPCShared

public actor RealtimeSuggestionController {
    public static let shared = RealtimeSuggestionController()

    private var listeners = Set<AnyHashable>()
    var eventObserver: CGEventObserverType = CGEventObserver(eventsOfInterest: [
        .keyUp,
        .keyDown,
        .rightMouseDown,
        .leftMouseDown,
    ])
    private var task: Task<Void, Error>?
    private var inflightPrefetchTask: Task<Void, Error>?
    private var ignoreUntil = Date(timeIntervalSince1970: 0)
    let realtimeSuggestionIndicatorController = RealtimeSuggestionIndicatorController()

    private init() {
        // Start the auto trigger if Xcode is running.
        Task {
            for xcode in await Environment.runningXcodes() {
                await start(by: xcode.processIdentifier)
            }
            let sequence = NSWorkspace.shared.notificationCenter
                .notifications(named: NSWorkspace.didActivateApplicationNotification)
            for await notification in sequence {
                try Task.checkCancellation()
                guard let app = notification
                    .userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
                else { continue }
                guard app.bundleIdentifier == "com.apple.dt.Xcode" else { continue }
                await start(by: app.processIdentifier)
            }
        }

        // Remove listener if Xcode is terminated.
        Task {
            let sequence = NSWorkspace.shared.notificationCenter
                .notifications(named: NSWorkspace.didTerminateApplicationNotification)
            for await notification in sequence {
                try Task.checkCancellation()
                guard let app = notification
                    .userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
                else { continue }
                guard app.bundleIdentifier == "com.apple.dt.Xcode" else { continue }
                await stop(by: app.processIdentifier)
            }
        }
    }

    private func start(by listener: AnyHashable) {
        os_log(.info, "Add auto trigger listener: %@.", listener as CVarArg)
        listeners.insert(listener)

        if task == nil {
            task = Task { [stream = eventObserver.stream] in
                for await event in stream {
                    await self.handleKeyboardEvent(event: event)
                }
            }
        }
        if eventObserver.activateIfPossible() {
            realtimeSuggestionIndicatorController?.isObserving = true
        }
    }

    private func stop(by listener: AnyHashable) {
        os_log(.info, "Remove auto trigger listener: %@.", listener as CVarArg)
        listeners.remove(listener)
        guard listeners.isEmpty else { return }
        os_log(.info, "Auto trigger is stopped.")
        task?.cancel()
        task = nil
        eventObserver.deactivate()
        realtimeSuggestionIndicatorController?.isObserving = false
    }

    func handleKeyboardEvent(event: CGEvent) async {
        await cancelInFlightTasks()

        if Task.isCancelled { return }
        guard await Environment.isXcodeActive() else { return }

        let escape = 0x35
        let arrowKeys = [0x7B, 0x7C, 0x7D, 0x7E]
        let isEditing = await Environment.frontmostXcodeWindowIsEditor()

        // if Xcode suggestion panel is presenting, and we are not trying to close it
        // ignore this event.
        if !isEditing, event.getIntegerValueField(.keyboardEventKeycode) != escape {
            return
        }

        let shouldTrigger = {
            let code = Int(event.getIntegerValueField(.keyboardEventKeycode))
            // closing auto-complete panel
            if isEditing, code == escape {
                return true
            }

            // escape and arrows to cancel

            if code == escape {
                return false
            }

            if arrowKeys.contains(code) {
                return false
            }

            // normally typing

            return event.type == .keyUp
        }()

        guard shouldTrigger else { return }
        guard Date().timeIntervalSince(ignoreUntil) > 0 else { return }

        inflightPrefetchTask = Task { @ServiceActor in
            try? await Task.sleep(nanoseconds: UInt64((
                UserDefaults.shared
                    .value(forKey: SettingsKey.realtimeSuggestionDebounce) as? Double
                    ?? 0.7
            ) * 1_000_000_000))
            guard UserDefaults.shared.bool(forKey: SettingsKey.realtimeSuggestionToggle)
            else { return }
            if Task.isCancelled { return }
            os_log(.info, "Prefetch suggestions.")
            realtimeSuggestionIndicatorController?.triggerPrefetchAnimation()
            do {
                try await Environment.triggerAction("Prefetch Suggestions")
            } catch {
                os_log(.info, "%@", error.localizedDescription)
            }
        }
    }

    func cancelInFlightTasks(excluding: Task<Void, Never>? = nil) async {
        inflightPrefetchTask?.cancel()

        // cancel in-flight tasks
        await withTaskGroup(of: Void.self) { group in
            for (_, workspace) in await workspaces {
                group.addTask {
                    await workspace.cancelInFlightRealtimeSuggestionRequests()
                }
            }
            group.addTask {
                await { @ServiceActor in
                    inflightRealtimeSuggestionsTasks.forEach {
                        if $0 == excluding { return }
                        $0.cancel()
                    }
                    inflightRealtimeSuggestionsTasks.removeAll()
                    if let excluded = excluding {
                        inflightRealtimeSuggestionsTasks.insert(excluded)
                    }
                }()
            }
        }
    }

    #warning("TODO: Find a better way to prevent that from happening!")
    /// Prevent prefetch to be triggered by commands. Quick and dirty.
    func cancelInFlightTasksAndIgnoreTriggerForAWhile(excluding: Task<Void, Never>? = nil) async {
        ignoreUntil = Date(timeIntervalSinceNow: 5)
        await cancelInFlightTasks(excluding: excluding)
    }
}

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
                .onAppear {
                    Task {
                        await Task.yield() // to avoid unwanted translations.
                        withAnimation(.easeInOut(duration: 1).repeatForever(autoreverses: true)) {
                            progress = 0
                        }
                    }
                }
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
    private var displayLink: CVDisplayLink!
    private var isDisplayLinkStarted: Bool = false
    private var userDefaultsObserver = UserDefaultsObserver()
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
        it.level = .statusBar
        it.contentView = NSHostingView(
            rootView: IndicatorContentView(viewModel: self.viewModel)
                .frame(minWidth: 10, minHeight: 10)
        )
        return it
    }()

    init?() {
        _ = CVDisplayLinkCreateWithCGDisplay(CGMainDisplayID(), &displayLink)
        guard displayLink != nil else { return nil }
        CVDisplayLinkSetOutputHandler(displayLink) { [weak self] _, _, _, _, _ in
            guard let self else { return kCVReturnSuccess }
            self.updateIndicatorLocation()
            return kCVReturnSuccess
        }

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
                CVDisplayLinkStart(self.displayLink)
            } else {
                CVDisplayLinkStop(self.displayLink)
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
                        window.setFrame(frame, display: false)
                        window.makeKey()
                        return
                    }
                }
            }

            var frame = window.frame
            let location = NSEvent.mouseLocation
            frame.origin = .init(x: location.x + 15, y: location.y + 15)
            frame.size = .init(width: 10, height: 10)
            window.setFrame(frame, display: false)
            window.makeKey()
        }
    }

    func triggerPrefetchAnimation() {
        Task { @MainActor in
            viewModel.prefetch()
        }
    }
}
