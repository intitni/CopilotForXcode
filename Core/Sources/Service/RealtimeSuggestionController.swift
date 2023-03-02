import ActiveApplicationMonitor
import AppKit
import AsyncAlgorithms
import AXNotificationStream
import CGEventObserver
import Environment
import Foundation
import os.log
import QuartzCore
import XPCShared

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

    private nonisolated init() {
        Task { [weak self] in

            if let app = ActiveApplicationMonitor.activeXcode {
                await self?.handleXcodeChanged(app)
                await startHIDObservation(by: 1)
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
        os_log(.info, "Add auto trigger listener: %@.", listener as CVarArg)

        if task == nil {
            task = Task { [stream = eventObserver.stream] in
                for await event in stream {
                    await self.handleHIDEvent(event: event)
                }
            }
        }
        eventObserver.activateIfPossible()
    }

    private func stopHIDObservation(by listener: AnyHashable) {
        os_log(.info, "Remove auto trigger listener: %@.", listener as CVarArg)
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
                    if await Environment.frontmostXcodeWindowIsEditor() {
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
                UserDefaults.shared
                    .value(forKey: SettingsKey.realtimeSuggestionDebounce) as? Double
                    ?? 0.7
            ) * 1_000_000_000))

            guard UserDefaults.shared.bool(forKey: SettingsKey.realtimeSuggestionToggle)
            else { return }

            if Task.isCancelled { return }

            os_log(.info, "Prefetch suggestions.")

            if !force, await !Environment.frontmostXcodeWindowIsEditor() {
                os_log(.info, "Completion panel is open, blocked.")
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

extension AXUIElement {
    var identifier: String {
        (try? copyValue(key: kAXIdentifierAttribute)) ?? ""
    }
    
    var value: String {
        (try? copyValue(key: kAXValueAttribute)) ?? ""
    }
    
    var focusedElement: AXUIElement? {
        try? copyValue(key: kAXFocusedUIElementAttribute)
    }

    var description: String {
        (try? copyValue(key: kAXDescriptionAttribute)) ?? ""
    }

    var selectedTextRange: Range<Int>? {
        guard let value: AXValue = try? copyValue(key: kAXSelectedTextRangeAttribute)
        else { return nil }
        var range: CFRange = .init(location: 0, length: 0)
        if AXValueGetValue(value, .cfRange, &range) {
            return Range(.init(location: range.location, length: range.length))
        }
        return nil
    }

    var sharedFocusElements: [AXUIElement] {
        (try? copyValue(key: kAXChildrenAttribute)) ?? []
    }

    var window: AXUIElement? {
        try? copyValue(key: kAXWindowAttribute)
    }

    var focusedWindow: AXUIElement? {
        try? copyValue(key: kAXFocusedWindowAttribute)
    }

    var topLevelElement: AXUIElement? {
        try? copyValue(key: kAXTopLevelUIElementAttribute)
    }

    var rows: [AXUIElement] {
        (try? copyValue(key: kAXRowsAttribute)) ?? []
    }

    var parent: AXUIElement? {
        try? copyValue(key: kAXParentAttribute)
    }

    var children: [AXUIElement] {
        (try? copyValue(key: kAXChildrenAttribute)) ?? []
    }

    var visibleChildren: [AXUIElement] {
        (try? copyValue(key: kAXVisibleChildrenAttribute)) ?? []
    }

    var isFocused: Bool {
        (try? copyValue(key: kAXFocusedAttribute)) ?? false
    }

    var isEnabled: Bool {
        (try? copyValue(key: kAXEnabledAttribute)) ?? false
    }

    func child(identifier: String) -> AXUIElement? {
        for child in children {
            if child.identifier == identifier { return child }
            if let target = child.child(identifier: identifier) { return target }
        }
        return nil
    }

    func visibleChild(identifier: String) -> AXUIElement? {
        for child in visibleChildren {
            if child.identifier == identifier { return child }
            if let target = child.visibleChild(identifier: identifier) { return target }
        }
        return nil
    }
}
