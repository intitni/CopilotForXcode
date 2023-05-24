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
import XcodeInspector

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
    private var sourceEditor: AXUIElement?

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
        focusedUIElement = focusElement

        Task { // Notify suggestion service for open file.
            try await Task.sleep(nanoseconds: 500_000_000)
            let fileURL = try await Environment.fetchCurrentFileURL()
            _ = try await Workspace.fetchOrCreateWorkspaceIfNeeded(fileURL: fileURL)
        }

        guard focusElementType == "Source Editor" else { return }
        sourceEditor = focusElement

        editorObservationTask?.cancel()
        editorObservationTask = nil

        editorObservationTask = Task { [weak self] in
            let notificationsFromEditor = AXNotificationStream(
                app: activeXcode,
                element: focusElement,
                notificationNames: kAXValueChangedNotification, kAXSelectedTextChangedNotification
            )

            for await notification in notificationsFromEditor {
                guard let self else { return }
                try Task.checkCancellation()
                await cancelInFlightTasks()

                switch notification.name {
                case kAXValueChangedNotification:
                    self.triggerPrefetchDebounced()
                    await self.notifyEditingFileChange(editor: focusElement)
                case kAXSelectedTextChangedNotification:
                    guard let editor = sourceEditor else { continue }
                    let sourceEditor = SourceEditor(
                        runningApplication: activeXcode,
                        element: editor
                    )
                    await PseudoCommandHandler()
                        .invalidateRealtimeSuggestionsIfNeeded(sourceEditor: sourceEditor)
                default:
                    continue
                }
            }
        }

        Task { // Get cache ready for real-time suggestions.
            guard UserDefaults.shared.value(for: \.preCacheOnFileOpen) else { return }
            let fileURL = try await Environment.fetchCurrentFileURL()
            let (_, filespace) = try await Workspace
                .fetchOrCreateWorkspaceIfNeeded(fileURL: fileURL)

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

        // Escape should cancel in-flight tasks.
        // Except that when the completion panel is presented, it should trigger prefetch instead.
        if keycode == escape {
            if event.type == .keyDown {
                await cancelInFlightTasks()
            } else {
                Task {
                    #warning(
                        "TODO: Any method to avoid using AppleScript to check that completion panel is presented?"
                    )
                    if isCommentMode, await Environment.frontmostXcodeWindowIsEditor() {
                        if Task.isCancelled { return }
                        self.triggerPrefetchDebounced(force: true)
                    }
                }
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

            if UserDefaults.shared.value(for: \.disableSuggestionFeatureGlobally),
               let fileURL = try? await Environment.fetchCurrentFileURL(),
               let (workspace, _) = try? await Workspace
               .fetchOrCreateWorkspaceIfNeeded(fileURL: fileURL)
            {
                let isEnabled = workspace.isSuggestionFeatureEnabled
                if !isEnabled { return }
            }

            if Task.isCancelled { return }

            Logger.service.info("Prefetch suggestions.")

            if !force, isCommentMode, await !Environment.frontmostXcodeWindowIsEditor() {
                Logger.service.info("Completion panel is open, blocked.")
                return
            }

            // So the editor won't be blocked (after information are cached)!
            await PseudoCommandHandler().generateRealtimeSuggestions(sourceEditor: sourceEditor)
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

    func notifyEditingFileChange(editor: AXUIElement) async {
        guard let fileURL = try? await Environment.fetchCurrentFileURL(),
              let (workspace, filespace) = try? await Workspace
              .fetchOrCreateWorkspaceIfNeeded(fileURL: fileURL)
        else { return }
        workspace.notifyUpdateFile(filespace: filespace, content: editor.value)
    }
}

