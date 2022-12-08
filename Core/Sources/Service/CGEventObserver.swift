import Cocoa
import Foundation

public protocol CGEventObserverType {
    @discardableResult
    func activateIfPossible() -> Bool
    func deactivate()
    var stream: AsyncStream<Void> { get }
    var isEnabled: Bool { get }
}

final class CGEventObserver: CGEventObserverType {
    let stream: AsyncStream<Void>
    var isEnabled: Bool { port != nil }

    private var continuation: AsyncStream<Void>.Continuation
    private var port: CFMachPort?
    private let eventsOfInterest: Set<CGEventType> = [.keyUp, .leftMouseUp, .mouseMoved]
    private let tapLocation: CGEventTapLocation = .cghidEventTap
    private let tapPlacement: CGEventTapPlacement = .tailAppendEventTap
    private let tapOptions: CGEventTapOptions = .listenOnly
    private var retryTask: Task<Void, Error>?

    deinit {
        continuation.finish()
        CFMachPortInvalidate(port)
    }

    init() {
        var continuation: AsyncStream<Void>.Continuation!
        stream = AsyncStream { c in
            continuation = c
        }
        self.continuation = continuation
    }

    public func deactivate() {
        retryTask?.cancel()
        retryTask = nil
        guard let port = port else { return }
        print("Deactivate")
        CFMachPortInvalidate(port)
        self.port = nil
    }

    @discardableResult
    public func activateIfPossible() -> Bool {
        guard AXIsProcessTrusted() else { return false }
        guard port == nil else { return true }

        let eoi = UInt64(eventsOfInterest.reduce(into: 0) { $0 |= 1 << $1.rawValue })

        func callback(
            tapProxy _: CGEventTapProxy,
            eventType: CGEventType,
            event: CGEvent,
            continuationPointer: UnsafeMutableRawPointer?
        ) -> Unmanaged<CGEvent>? {
            guard AXIsProcessTrusted() else {
                return .passRetained(event)
            }

            if eventType == .tapDisabledByTimeout || eventType == .tapDisabledByUserInput {
                return .passRetained(event)
            }

            if let continuation = continuationPointer?.assumingMemoryBound(to: AsyncStream<Void>.Continuation.self) {
                continuation.pointee.yield(())
            }

            return .passRetained(event)
        }

        let tapLocation = self.tapLocation
        let tapPlacement = self.tapPlacement
        let tapOptions = self.tapOptions

        guard let port = withUnsafeMutablePointer(to: &continuation, { pointer in
            CGEvent.tapCreate(
                tap: tapLocation,
                place: tapPlacement,
                options: tapOptions,
                eventsOfInterest: eoi,
                callback: callback,
                userInfo: pointer
            )
        }) else {
            retryTask = Task {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                try Task.checkCancellation()
                activateIfPossible()
            }
            return false
        }
        self.port = port
        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, port, 0)
        CFRunLoopAddSource(RunLoop.main.getCFRunLoop(), runLoopSource, .commonModes)
        return true
    }
}
