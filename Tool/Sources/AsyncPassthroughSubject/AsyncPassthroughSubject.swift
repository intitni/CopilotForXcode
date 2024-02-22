import AppKit
import Foundation

public actor AsyncPassthroughSubject<Element> {
    var tasks: [AsyncStream<Element>.Continuation] = []

    deinit {
        tasks.forEach { $0.finish() }
    }
    
    public init() {}

    public func notifications() -> AsyncStream<Element> {
        AsyncStream { [weak self] continuation in
            let task = Task { [weak self] in
                await self?.storeContinuation(continuation)
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
        let tasks = tasks
        for task in tasks {
            task.yield(element)
        }
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

