import AppKit
import Foundation

/// It uses notification center to mimic the behavior of a passthrough subject.
public actor AsyncPassthroughSubject<Element> {
    let name: Notification.Name
    var tasks: [AsyncStream<Element>.Continuation] = []

    deinit {
        tasks.forEach { $0.finish() }
    }
    
    public init() {
        name = NSNotification.Name(
            "AsyncPassthroughSubject-\(UUID().uuidString)-\(String(describing: Element.self))"
        )
    }

    public func notifications() -> AsyncStream<Element> {
        AsyncStream { [weak self, name] continuation in
            let task = Task { [weak self] in
                await self?.storeContinuation(continuation)
                let notifications = NSWorkspace.shared.notificationCenter.notifications(named: name)
                    .compactMap {
                        $0.object as? Element
                    }
                for await notification in notifications {
                    try Task.checkCancellation()
                    guard self != nil else {
                        continuation.finish()
                        return
                    }
                    continuation.yield(notification)
                }
            }
            
            continuation.onTermination = { termination in
                task.cancel()
            }
        }
    }

    nonisolated
    public func send(_ element: Element) {
        Task { await _send(element) }
    }
    
    func _send(_ element: Element) {
        NSWorkspace.shared.notificationCenter.post(name: name, object: element)
    }
    
    func storeContinuation(_ continuation: AsyncStream<Element>.Continuation) {
        tasks.append(continuation)
    }
    
    nonisolated
    public func finish() {
        Task { await _finish() }
    }
    
    func _finish() {
        let tasks = self.tasks
        self.tasks = []
        for task in tasks {
            task.finish()
        }
    }
}

