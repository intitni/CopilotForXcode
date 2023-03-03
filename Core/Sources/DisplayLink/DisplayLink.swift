import Foundation
import QuartzCore

public actor DisplayLink {
    private var displayLink: CVDisplayLink!
    private static var _shared = DisplayLink()
    static var shared: DisplayLink? {
        if let _shared { return _shared }
        _shared = DisplayLink()
        return _shared
    }

    private var continuations: [UUID: AsyncStream<Void>.Continuation] = [:]

    public static func createStream() -> AsyncStream<Void> {
        .init { continuation in
            Task {
                let id = UUID()
                await DisplayLink.shared?.addContinuation(continuation, id: id)
                continuation.onTermination = { _ in
                    Task {
                        await DisplayLink.shared?.removeContinuation(id: id)
                    }
                }
            }
        }
    }

    private init?() {
        _ = CVDisplayLinkCreateWithCGDisplay(CGMainDisplayID(), &displayLink)
        guard displayLink != nil else { return nil }
        CVDisplayLinkSetOutputHandler(displayLink) { [weak self] _, _, _, _, _ in
            guard let self else { return kCVReturnSuccess }
            Task { await self.notifyContinuations() }
            return kCVReturnSuccess
        }
    }

    deinit {
        for continuation in continuations {
            continuation.value.finish()
        }
    }

    func addContinuation(_ continuation: AsyncStream<Void>.Continuation, id: UUID) {
        continuations[id] = continuation
        if !continuations.isEmpty {
            CVDisplayLinkStart(displayLink)
        }
    }

    func removeContinuation(id: UUID) {
        continuations[id] = nil
        if continuations.isEmpty {
            CVDisplayLinkStop(displayLink)
        }
    }

    private func notifyContinuations() {
        for continuation in continuations {
            continuation.value.yield()
        }
    }
}
