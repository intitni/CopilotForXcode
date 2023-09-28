import AppKit

public final class ActiveApplicationMonitor {
    public static let shared = ActiveApplicationMonitor()
    public private(set) var latestXcode: NSRunningApplication? = NSWorkspace.shared
        .runningApplications
        .first(where: \.isXcode)
    public private(set) var previousApp: NSRunningApplication?
    public private(set) var activeApplication = NSWorkspace.shared.runningApplications
        .first(where: \.isActive)
    {
        didSet {
            if activeApplication?.isXcode ?? false {
                latestXcode = activeApplication
            }
            previousApp = oldValue
        }
    }

    private var continuations: [UUID: AsyncStream<NSRunningApplication?>.Continuation] = [:]

    private init() {
        activeApplication = NSWorkspace.shared.runningApplications.first(where: \.isActive)
        
        Task {
            let sequence = NSWorkspace.shared.notificationCenter
                .notifications(named: NSWorkspace.didActivateApplicationNotification)
            for await notification in sequence {
                guard let app = notification
                    .userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
                else { continue }
                activeApplication = app
                notifyContinuations()
            }
        }
    }

    deinit {
        for continuation in continuations {
            continuation.value.finish()
        }
    }

    public var activeXcode: NSRunningApplication? {
        if activeApplication?.isXcode ?? false {
            return activeApplication
        }
        return nil
    }

    public func createStream() -> AsyncStream<NSRunningApplication?> {
        .init { continuation in
            let id = UUID()
            Task { @MainActor in
                continuation.onTermination = { _ in
                    self.removeContinuation(id: id)
                }
                addContinuation(continuation, id: id)
                continuation.yield(activeApplication)
            }
        }
    }

    func addContinuation(
        _ continuation: AsyncStream<NSRunningApplication?>.Continuation,
        id: UUID
    ) {
        continuations[id] = continuation
    }

    func removeContinuation(id: UUID) {
        continuations[id] = nil
    }

    private func notifyContinuations() {
        for continuation in continuations {
            continuation.value.yield(activeApplication)
        }
    }
}

public extension NSRunningApplication {
    var isXcode: Bool { bundleIdentifier == "com.apple.dt.Xcode" }
}

