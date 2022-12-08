import Foundation
import XPCShared

actor AutoTrigger {
    static let shared = AutoTrigger()

    private var listeners = Set<ObjectIdentifier>()
    var eventObserver: CGEventObserverType = CGEventObserver()
    var task: Task<Void, Error>?

    private init() {}

    func start(by listener: ObjectIdentifier) {
        listeners.insert(listener)
        if task == nil {
            task = Task { [stream = eventObserver.stream] in
                var triggerTask: Task<Void, Error>?
                try? await Environment.triggerAction("Realtime Suggestions")
                for await _ in stream {
                    triggerTask?.cancel()
                    if Task.isCancelled { break }
                    triggerTask = Task {
                        try? await Task.sleep(nanoseconds: 2_000_000_000)
                        if Task.isCancelled { return }
                        try? await Environment.triggerAction("Realtime Suggestions")
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
