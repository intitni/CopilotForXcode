import Cocoa
import Foundation
import Logger

public protocol CGEventObserverType {
    @discardableResult
    func activateIfPossible() -> Bool
    func deactivate()
    func createStream() -> AsyncStream<CGEvent>
    var isEnabled: Bool { get }
}

public final class CGEventObserver: CGEventObserverType {
    public var isEnabled: Bool { port != nil }

    private var continuations: [UUID: AsyncStream<CGEvent>.Continuation] = [:]
    private var port: CFMachPort?
    private let eventsOfInterest: Set<CGEventType>
    private let tapLocation: CGEventTapLocation = .cghidEventTap
    private let tapPlacement: CGEventTapPlacement = .tailAppendEventTap
    private let tapOptions: CGEventTapOptions = .defaultTap

    deinit {
        for continuation in continuations {
            continuation.value.finish()
        }
        CFMachPortInvalidate(port)
    }

    public init(eventsOfInterest: Set<CGEventType>) {
        self.eventsOfInterest = eventsOfInterest
    }

    public func createStream() -> AsyncStream<CGEvent> {
        .init { continuation in
            let id = UUID()
            addContinuation(continuation, id: id)
            continuation.onTermination = { [weak self] _ in
                self?.removeContinuation(id: id)
            }
        }
    }

    private func addContinuation(_ continuation: AsyncStream<CGEvent>.Continuation, id: UUID) {
        continuations[id] = continuation
    }

    private func removeContinuation(id: UUID) {
        continuations[id] = nil
    }

    public func deactivate() {
        guard let port else { return }
        Logger.service.info("CGEventObserver deactivated.")
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
            continuationsPointer: UnsafeMutableRawPointer?
        ) -> Unmanaged<CGEvent>? {
            guard AXIsProcessTrusted() else {
                return .passRetained(event)
            }

            if eventType == .tapDisabledByTimeout || eventType == .tapDisabledByUserInput {
                return .passRetained(event)
            }

            if let continuations = continuationsPointer?
                .assumingMemoryBound(to: [UUID: AsyncStream<CGEvent>.Continuation].self)
            {
                for continuation in continuations.pointee {
                    continuation.value.yield(event)
                }
            }

            return .passRetained(event)
        }

        let tapLocation = tapLocation
        let tapPlacement = tapPlacement
        let tapOptions = tapOptions

        guard let port = withUnsafeMutablePointer(to: &continuations, { pointer in
            CGEvent.tapCreate(
                tap: tapLocation,
                place: tapPlacement,
                options: tapOptions,
                eventsOfInterest: eoi,
                callback: callback,
                userInfo: pointer
            )
        }) else {
            return false
        }
        self.port = port
        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, port, 0)
        CFRunLoopAddSource(RunLoop.main.getCFRunLoop(), runLoopSource, .commonModes)
        Logger.service.info("CGEventObserver activated.")
        return true
    }
}
