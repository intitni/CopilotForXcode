import Foundation
import XPCShared

actor AutoTrigger {
    static let shared = AutoTrigger()

    var listeners = Set<ObjectIdentifier>()
    private var task: Task<Void, Error>?

    private init() {}

    func start(by listener: ObjectIdentifier) {
        listeners.insert(listener)
        guard task == nil else { return }
        task = Task {
            while !Task.isCancelled {
                guard UserDefaults.shared.bool(forKey: SettingsKey.isAutoTriggerEnabled) else {
                    continue
                }
                try await Task.sleep(nanoseconds: 2_000_000_000)
                try? await Environment.triggerAction("Realtime Suggestions")
                print("run")
            }
        }
    }

    func stop(by listener: ObjectIdentifier) {
        listeners.remove(listener)
        guard listeners.isEmpty else { return }
        task?.cancel()
        task = nil
    }
}
