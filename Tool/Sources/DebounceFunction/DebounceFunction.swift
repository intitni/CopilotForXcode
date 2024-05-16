import Foundation

public actor DebounceFunction<T> {
    let duration: TimeInterval
    let block: (T) async -> Void

    var task: Task<Void, Error>?

    public init(duration: TimeInterval, block: @escaping (T) async -> Void) {
        self.duration = duration
        self.block = block
    }

    public func cancel() {
        task?.cancel()
    }

    public func callAsFunction(_ t: T) async {
        task?.cancel()
        task = Task { [block, duration] in
            try await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            await block(t)
        }
    }
}

public actor DebounceRunner {
    let duration: TimeInterval

    var task: Task<Void, Error>?

    public init(duration: TimeInterval) {
        self.duration = duration
    }

    public func cancel() {
        task?.cancel()
    }

    public func debounce(_ block: @escaping () async -> Void) {
        task?.cancel()
        task = Task { [duration] in
            try await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            await block()
        }
    }
}

