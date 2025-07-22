import AppKit
import Foundation

public actor AsyncPassthroughSubject<Element> {
    var tasks: [UUID: AsyncStream<Element>.Continuation] = [:]

    deinit {
        tasks.values.forEach { $0.finish() }
    }

    public init() {}

    public func notifications() -> AsyncStream<Element> {
        AsyncStream { [weak self] continuation in
            let id = UUID()
            let task = Task { [weak self] in
                await self?.storeContinuation(continuation, for: id)
            }

            continuation.onTermination = { [weak self] _ in
                task.cancel()
                Task {
                    await self?.removeContinuation(for: id)
                }
            }
        }
    }

    public nonisolated
    func send(_ element: Element) {
        Task { await _send(element) }
    }

    func _send(_ element: Element) {
        let tasks = tasks
        for task in tasks.values {
            task.yield(element)
        }
    }

    func storeContinuation(_ continuation: AsyncStream<Element>.Continuation, for id: UUID) {
        tasks[id] = continuation
    }

    func removeContinuation(for id: UUID) {
        tasks.removeValue(forKey: id)
    }

    public nonisolated
    func finish() {
        Task { await _finish() }
    }

    func _finish() {
        let tasks = self.tasks
        self.tasks = [:]
        for task in tasks.values {
            task.finish()
        }
    }
}

