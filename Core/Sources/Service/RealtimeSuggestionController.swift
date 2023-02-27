import ActiveApplicationMonitor
import AppKit
import CGEventObserver
import Foundation
import os.log
import XPCShared

public actor RealtimeSuggestionController {
    public static let shared = RealtimeSuggestionController()
    var eventObserver: CGEventObserverType = CGEventObserver(eventsOfInterest: [
        .keyUp,
        .keyDown,
        .rightMouseDown,
        .leftMouseDown,
    ])
    private var task: Task<Void, Error>?
    private var inflightPrefetchTask: Task<Void, Error>?
    private var ignoreUntil = Date(timeIntervalSince1970: 0)
    var realtimeSuggestionIndicatorController: RealtimeSuggestionIndicatorController {
        GraphicalUserInterfaceController.shared.realtimeSuggestionIndicatorController
    }

    private init() {
        Task {
            for await _ in ActiveApplicationMonitor.createStream() {
                try Task.checkCancellation()
                if ActiveApplicationMonitor.activeXcode != nil {
                    await start(by: 1)
                } else {
                    await stop(by: 1)
                }
            }
        }
    }

    private func start(by listener: AnyHashable) {
        os_log(.info, "Add auto trigger listener: %@.", listener as CVarArg)

        if task == nil {
            task = Task { [stream = eventObserver.stream] in
                for await event in stream {
                    await self.handleKeyboardEvent(event: event)
                }
            }
        }
        if eventObserver.activateIfPossible() {
            realtimeSuggestionIndicatorController.isObserving = true
        }
    }

    private func stop(by listener: AnyHashable) {
        os_log(.info, "Remove auto trigger listener: %@.", listener as CVarArg)
        os_log(.info, "Auto trigger is stopped.")
        task?.cancel()
        task = nil
        eventObserver.deactivate()
        realtimeSuggestionIndicatorController.isObserving = false
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
            await realtimeSuggestionIndicatorController.triggerPrefetchAnimation()
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
