import Foundation
import XPCShared

actor AutoTrigger {
    static let shared = AutoTrigger()

    private var listeners = Set<ObjectIdentifier>()
    var eventObserver: CGEventObserverType = CGEventObserver()
    var task: Task<Void, Error>?

    private init() {
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
    }

    func start(by listener: ObjectIdentifier) {
        listeners.insert(listener)
        if task == nil {
            task = Task { [stream = eventObserver.stream] in
                var triggerTask: Task<Void, Error>?
                try? await Environment.triggerAction("Real-time Suggestions")
                for await _ in stream {
                    triggerTask?.cancel()
                    if Task.isCancelled { break }
                    guard await Environment.isXcodeActive() else { continue }

                    await withTaskGroup(of: Void.self) { group in
                        for (_, workspace) in await workspaces {
                            group.addTask {
                                await workspace.cancelAllRealtimeSuggestionFulfillmentTasks()
                            }
                        }
                    }

                    triggerTask = Task { @ServiceActor in
                        try? await Task.sleep(nanoseconds: 2_500_000_000)
                        if Task.isCancelled { return }
                        let fileURL = try? await Environment.fetchCurrentFileURL()
                        guard let folderURL = try? await Environment.fetchCurrentProjectRootURL(fileURL),
                              let workspace = workspaces[folderURL],
                              workspace.isRealtimeSuggestionEnabled
                        else { return }
                        try? await Environment.triggerAction("Real-time Suggestions")
                    }
                }
            }
        }
        eventObserver.activateIfPossible()
    }

    func stop(by listener: ObjectIdentifier) {
        listeners.remove(listener)
        guard listeners.isEmpty else { return }
        task?.cancel()
        task = nil
        eventObserver.deactivate()
    }
}
