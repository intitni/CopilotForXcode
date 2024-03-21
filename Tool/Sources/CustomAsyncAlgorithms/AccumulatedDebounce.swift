import Foundation

/// Debounce, at the same time accumulate the values
public extension AsyncSequence {
    func accumulatedDebounce<R>(
        duration: TimeInterval,
        initialValue: @escaping @autoclosure () -> R,
        accumulate: @escaping (R, Element) -> R
    ) -> AsyncThrowingStream<R, Error> {
        AsyncThrowingStream { continuation in
            Task {
                var lastFireTime = Date()
                var value = initialValue()
                do {
                    for try await item in self {
                        value = accumulate(value, item)
                        let now = Date()
                        if now.timeIntervalSince(lastFireTime) > duration {
                            lastFireTime = now
                            continuation.yield(value)
                            value = initialValue()
                            print(value)
                        }
                    }
                    continuation.yield(value)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}

