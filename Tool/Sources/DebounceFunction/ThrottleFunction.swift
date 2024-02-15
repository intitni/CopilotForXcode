import Foundation

public actor ThrottleFunction<T> {
    let duration: TimeInterval
    let block: (T) async -> Void

    var task: Task<Void, Error>?
    var lastFinishTime: Date = .init(timeIntervalSince1970: 0)
    var now: () -> Date = { Date() }

    public init(duration: TimeInterval, block: @escaping (T) async -> Void) {
        self.duration = duration
        self.block = block
    }

    public func callAsFunction(_ t: T) async {
        if task == nil {
            scheduleTask(t, wait: now().timeIntervalSince(lastFinishTime) < duration)
        }
    }

    func scheduleTask(_ t: T, wait: Bool) {
        task = Task.detached { [weak self] in
            guard let self else { return }
            do {
                if wait {
                    try await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
                }
                await block(t)
                await finishTask()
            } catch {
                await finishTask()
            }
        }
    }

    func finishTask() {
        task = nil
        lastFinishTime = now()
    }
}

