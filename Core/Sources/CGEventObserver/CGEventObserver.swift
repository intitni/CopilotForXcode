import Cocoa
import Foundation
import os.log

public protocol CGEventObserverType {
    @discardableResult
    func activateIfPossible() -> Bool
    func deactivate()
    var stream: AsyncStream<CGEvent> { get }
    var isEnabled: Bool { get }
}

public final class CGEventObserver: CGEventObserverType {
    public let stream: AsyncStream<CGEvent>
    public var isEnabled: Bool { port != nil }

    private var continuation: AsyncStream<CGEvent>.Continuation
    private var port: CFMachPort?
    private let eventsOfInterest: Set<CGEventType>
    private let tapLocation: CGEventTapLocation = .cghidEventTap
    private let tapPlacement: CGEventTapPlacement = .tailAppendEventTap
    private let tapOptions: CGEventTapOptions = .listenOnly
    private var retryTask: Task<Void, Error>?

    deinit {
        continuation.finish()
        CFMachPortInvalidate(port)
    }

    public init(eventsOfInterest: Set<CGEventType>) {
        self.eventsOfInterest = eventsOfInterest
        var continuation: AsyncStream<CGEvent>.Continuation!
        stream = AsyncStream { c in
            continuation = c
        }
        self.continuation = continuation
    }

    public func deactivate() {
        retryTask?.cancel()
        retryTask = nil
        guard let port else { return }
        os_log(.info, "CGEventObserver deactivated.")
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

            if let continuation = continuationPointer?
                .assumingMemoryBound(to: AsyncStream<CGEvent>.Continuation.self)
            {
                continuation.pointee.yield(event)
            }

            return .passRetained(event)
        }

        let tapLocation = tapLocation
        let tapPlacement = tapPlacement
        let tapOptions = tapOptions

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
        os_log(.info, "CGEventObserver activated.")
        return true
    }
}
