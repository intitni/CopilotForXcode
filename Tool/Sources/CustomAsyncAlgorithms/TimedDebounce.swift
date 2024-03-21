import Foundation

private actor TimedDebounceFunction<Element> {
    let duration: TimeInterval
    let block: (Element) async -> Void

    var task: Task<Void, Error>?
    var lastValue: Element?
    var lastFireTime: Date = .init(timeIntervalSince1970: 0)

    init(duration: TimeInterval, block: @escaping (Element) async -> Void) {
        self.duration = duration
        self.block = block
    }

    func callAsFunction(_ value: Element) async {
        task?.cancel()
        if lastFireTime.timeIntervalSinceNow < -duration {
            await fire(value)
            task = nil
        } else {
            lastValue = value
            task = Task.detached { [weak self, duration] in
                try await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
                await self?.fire(value)
            }
        }
    }

    func finish() async {
        task?.cancel()
        if let lastValue {
            await fire(lastValue)
        }
    }

    private func fire(_ value: Element) async {
        lastFireTime = Date()
        lastValue = nil
        await block(value)
    }
}

public extension AsyncSequence {
    /// Debounce, but only if the value is received within a certain time frame.
    ///
    /// In the future when we drop macOS 12 support we should just use chunked from AsyncAlgorithms.
    func timedDebounce(
        for duration: TimeInterval
    ) -> AsyncThrowingStream<Element, Error> {
        return AsyncThrowingStream { continuation in
            Task {
                let function = TimedDebounceFunction(duration: duration) { value in
                    continuation.yield(value)
                }
                do {
                    for try await value in self {
                        await function(value)
                    }
                    await function.finish()
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}

