import AppKit

public final class ActiveApplicationMonitor {
    static let shared = ActiveApplicationMonitor()
    var latestXcode: NSRunningApplication? = NSWorkspace.shared.runningApplications
        .first(where: \.isXcode)
    var previousApp: NSRunningApplication?
    var activeApplication = NSWorkspace.shared.runningApplications.first(where: \.isActive) {
        didSet {
            if activeApplication?.isXcode ?? false {
                latestXcode = activeApplication
            }
            previousApp = oldValue
        }
    }

    private var continuations: [UUID: AsyncStream<NSRunningApplication?>.Continuation] = [:]

    private init() {
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

    public static var activeApplication: NSRunningApplication? { shared.activeApplication }
    
    public static var previousActiveApplication: NSRunningApplication? { shared.previousApp }

    public static var activeXcode: NSRunningApplication? {
        if activeApplication?.isXcode ?? false {
            return activeApplication
        }
        return nil
    }

    public static var latestXcode: NSRunningApplication? { shared.latestXcode }

    public static func createStream() -> AsyncStream<NSRunningApplication?> {
        .init { continuation in
            let id = UUID()
            ActiveApplicationMonitor.shared.addContinuation(continuation, id: id)
            continuation.onTermination = { _ in
                ActiveApplicationMonitor.shared.removeContinuation(id: id)
            }
            continuation.yield(activeApplication)
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

