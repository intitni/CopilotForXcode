import AppKit
import Foundation
import os.log
import XPCShared

public actor AutoTrigger {
    public static let shared = AutoTrigger()

    private var listeners = Set<AnyHashable>()
    var eventObserver: CGEventObserverType = CGEventObserver()
    var task: Task<Void, Error>?

    private init() {
        // Occasionally cleanup workspaces.
        Task { @ServiceActor in
            while !Task.isCancelled {
                try await Task.sleep(nanoseconds: 8 * 60 * 60 * 1_000_000_000)
                for (url, workspace) in workspaces {
                    if workspace.isExpired {
                        workspaces[url] = nil
                    } else {
                        workspaces[url]?.cleanUp()
                    }
                }
            }
        }

        // Start the auto trigger if Xcode is running.
        Task {
            for xcode in await Environment.runningXcodes() {
                await start(by: xcode.processIdentifier)
            }
            let sequence = NSWorkspace.shared.notificationCenter
                .notifications(named: NSWorkspace.didLaunchApplicationNotification)
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

    func start(by listener: AnyHashable) {
        os_log(.info, "Add auto trigger listener: %@.", listener as CVarArg)
        listeners.insert(listener)

        if task == nil {
            task = Task { [stream = eventObserver.stream] in
                var triggerTask: Task<Void, Error>?
                for await _ in stream {
                    triggerTask?.cancel()
                    if Task.isCancelled { break }
                    guard await Environment.isXcodeActive() else { continue }

                    await withTaskGroup(of: Void.self) { group in
                        for (_, workspace) in await workspaces {
                            group.addTask {
                                await workspace.cancelInFlightRealtimeSuggestionRequests()
                            }
                        }
                    }

                    triggerTask = Task { @ServiceActor in
                        try? await Task.sleep(nanoseconds: 2_000_000_000)
                        if Task.isCancelled { return }
                        let fileURL = try? await Environment.fetchCurrentFileURL()
                        guard let folderURL = try? await Environment
                            .fetchCurrentProjectRootURL(fileURL)
                        else { return }
                        let workspace = workspaces[folderURL] ??
                            Workspace(projectRootURL: folderURL)
                        workspaces[folderURL] = workspace
                        guard workspace.isRealtimeSuggestionEnabled else { return }
                        if Task.isCancelled { return }
                        try? await Environment.triggerAction("Prefetch Suggestions")
                    }
                }
            }
        }
        eventObserver.activateIfPossible()
    }

    func stop(by listener: AnyHashable) {
        os_log(.info, "Remove auto trigger listener: %@.", listener as CVarArg)
        listeners.remove(listener)
        guard listeners.isEmpty else { return }
        os_log(.info, "Auto trigger is stopped.")
        task?.cancel()
        task = nil
        eventObserver.deactivate()
    }
}
