import ActiveApplicationMonitor
import AppKit
import AsyncAlgorithms
import AXExtension
import AXNotificationStream
import CGEventObserver
import Environment
import Foundation
import Logger
import Preferences
import QuartzCore

@ServiceActor
public class RealtimeSuggestionController {
    public nonisolated static let shared = RealtimeSuggestionController()
    var eventObserver: CGEventObserverType = CGEventObserver(eventsOfInterest: [
        .keyUp,
        .keyDown,
        .rightMouseDown,
        .leftMouseDown,
    ])
    private var task: Task<Void, Error>?
    private var inflightPrefetchTask: Task<Void, Error>?
    private var windowChangeObservationTask: Task<Void, Error>?
    private var activeApplicationMonitorTask: Task<Void, Error>?
    private var editorObservationTask: Task<Void, Error>?
    private var focusedUIElement: AXUIElement?

    var isCommentMode: Bool {
        UserDefaults.shared.value(for: \.suggestionPresentationMode) == .comment
    }

    private nonisolated init() {
        Task { [weak self] in

            if let app = ActiveApplicationMonitor.activeXcode {
                await self?.handleXcodeChanged(app)
                await self?.startHIDObservation(by: 1)
            }
            var previousApp = ActiveApplicationMonitor.activeXcode
            for await app in ActiveApplicationMonitor.createStream() {
                guard let self else { return }
                try Task.checkCancellation()
                defer { previousApp = app }

                if let app = ActiveApplicationMonitor.activeXcode, app != previousApp {
                    await self.handleXcodeChanged(app)
                }

                #warning(
                    "TOOD: Is it possible to get rid of hid event observation with only AXObserver?"
                )
                if ActiveApplicationMonitor.activeXcode != nil {
                    await startHIDObservation(by: 1)
                } else {
                    await stopHIDObservation(by: 1)
                }
            }
        }
    }

    private func startHIDObservation(by listener: AnyHashable) {
        Logger.service.info("Add auto trigger listener: \(listener).")

        if task == nil {
            task = Task { [weak self, eventObserver] in
                for await event in eventObserver.createStream() {
                    guard let self else { return }
                    await self.handleHIDEvent(event: event)
                }
            }
        }
        eventObserver.activateIfPossible()
    }

    private func stopHIDObservation(by listener: AnyHashable) {
        Logger.service.info("Remove auto trigger listener: \(listener).")
        task?.cancel()
        task = nil
        eventObserver.deactivate()
    }

    private func handleXcodeChanged(_ app: NSRunningApplication) {
        windowChangeObservationTask?.cancel()
        windowChangeObservationTask = nil
        observeXcodeWindowChangeIfNeeded(app)
    }

    private func observeXcodeWindowChangeIfNeeded(_ app: NSRunningApplication) {
        guard windowChangeObservationTask == nil else { return }
        handleFocusElementChange()
        windowChangeObservationTask = Task { [weak self] in
            let notifications = AXNotificationStream(
                app: app,
                notificationNames: kAXFocusedUIElementChangedNotification,
                kAXMainWindowChangedNotification
            )
            for await _ in notifications {
                guard let self else { return }
                try Task.checkCancellation()
                self.handleFocusElementChange()
            }
        }
    }

    private func handleFocusElementChange() {
        guard let activeXcode = ActiveApplicationMonitor.activeXcode else { return }
        let application = AXUIElementCreateApplication(activeXcode.processIdentifier)
        guard let focusElement = application.focusedElement else { return }
        let focusElementType = focusElement.description
        guard focusElementType == "Source Editor" else { return }
        focusedUIElement = focusElement

        editorObservationTask?.cancel()
        editorObservationTask = nil

        editorObservationTask = Task { [weak self] in
            let notificationsFromEditor = AXNotificationStream(
                app: activeXcode,
                element: focusElement,
                notificationNames: kAXValueChangedNotification
            )

            for await notification in notificationsFromEditor {
                guard let self else { return }
                try Task.checkCancellation()
                await cancelInFlightTasks()

                switch notification.name {
                case kAXValueChangedNotification:
                    self.triggerPrefetchDebounced()
                default:
                    continue
                }
            }
        }

        Task { // Get cache ready for real-time suggestions.
            guard
                let fileURL = try? await Environment.fetchCurrentFileURL(),
                let (_, filespace) = try? await Workspace
                .fetchOrCreateWorkspaceIfNeeded(fileURL: fileURL)
            else { return }

            if filespace.uti == nil {
                Logger.service.info("Generate cache for file.")
                // avoid the command get called twice
                filespace.uti = ""
                do {
                    try await Environment.triggerAction("Real-time Suggestions")
                } catch {
                    if filespace.uti?.isEmpty ?? true {
                        filespace.uti = nil
                    }
                }
            }
        }
    }

    func handleHIDEvent(event: CGEvent) async {
        guard await Environment.isXcodeActive() else { return }

        // Mouse clicks should cancel in-flight tasks.
        if [CGEventType.rightMouseDown, .leftMouseDown].contains(event.type) {
            await cancelInFlightTasks()
            return
        }

        let keycode = Int(event.getIntegerValueField(.keyboardEventKeycode))
        let escape = 0x35
        let arrowKeys = [0x7B, 0x7C, 0x7D, 0x7E]

        // Arrow keys should cancel in-flight tasks.
        if arrowKeys.contains(keycode) {
            await cancelInFlightTasks()
            return
        }

        // Escape should cancel in-flight tasks.
        // Except that when the completion panel is presented, it should trigger prefetch instead.
        if keycode == escape {
            if event.type == .keyDown {
                await cancelInFlightTasks()
            } else {
                let task = Task {
                    #warning(
                        "TODO: Any method to avoid using AppleScript to check that completion panel is presented?"
                    )
                    if isCommentMode, await Environment.frontmostXcodeWindowIsEditor() {
                        if Task.isCancelled { return }
                        self.triggerPrefetchDebounced(force: true)
                    }
                }
                inflightRealtimeSuggestionsTasks.insert(task)
            }
        }
    }

    func triggerPrefetchDebounced(force: Bool = false) {
        inflightPrefetchTask = Task { @ServiceActor in
            try? await Task.sleep(nanoseconds: UInt64((
                UserDefaults.shared.value(for: \.realtimeSuggestionDebounce)
            ) * 1_000_000_000))

            guard UserDefaults.shared.value(for: \.realtimeSuggestionToggle)
            else { return }

            if Task.isCancelled { return }

            Logger.service.info("Prefetch suggestions.")

            if !force, isCommentMode, await !Environment.frontmostXcodeWindowIsEditor() {
                Logger.service.info("Completion panel is open, blocked.")
                return
            }

            // So the editor won't be blocked (after information are cached)!
            await PseudoCommandHandler().generateRealtimeSuggestions()
        }
    }

    func cancelInFlightTasks(excluding: Task<Void, Never>? = nil) async {
        inflightPrefetchTask?.cancel()

        // cancel in-flight tasks
        await withTaskGroup(of: Void.self) { group in
            for (_, workspace) in workspaces {
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

    /// This method will still return true if the completion panel is hidden by esc.
    /// Looks like the Xcode will keep the panel around until content is changed,
    /// not sure how to observe that it's hidden.
    func isCompletionPanelPresenting() -> Bool {
        guard let activeXcode = ActiveApplicationMonitor.activeXcode else { return false }
        let application = AXUIElementCreateApplication(activeXcode.processIdentifier)
        return application.focusedWindow?.child(identifier: "_XC_COMPLETION_TABLE_") != nil
    }
}
