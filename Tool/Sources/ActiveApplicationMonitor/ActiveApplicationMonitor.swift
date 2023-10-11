import AppKit

public struct RunningApplicationInfo: Sendable {
    public let isXcode: Bool
    public let isActive: Bool
    public let isHidden: Bool
    public let localizedName: String?
    public let bundleIdentifier: String?
    public let bundleURL: URL?
    public let executableURL: URL?
    public let processIdentifier: pid_t
    public let launchDate: Date?
    public let executableArchitecture: Int

    init(_ application: NSRunningApplication) {
        isXcode = application.isXcode
        isActive = application.isActive
        isHidden = application.isHidden
        localizedName = application.localizedName
        bundleIdentifier = application.bundleIdentifier
        bundleURL = application.bundleURL
        executableURL = application.executableURL
        processIdentifier = application.processIdentifier
        launchDate = application.launchDate
        executableArchitecture = application.executableArchitecture
    }
}

public extension NSRunningApplication {
    var info: RunningApplicationInfo { RunningApplicationInfo(self) }
}

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

    private var infoContinuations: [UUID: AsyncStream<RunningApplicationInfo?>.Continuation] = [:]

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
        for continuation in infoContinuations {
            continuation.value.finish()
        }
    }

    public var activeXcode: NSRunningApplication? {
        if activeApplication?.isXcode ?? false {
            return activeApplication
        }
        return nil
    }

    public func createInfoStream() -> AsyncStream<RunningApplicationInfo?> {
        .init { continuation in
            let id = UUID()
            Task { @MainActor in
                continuation.onTermination = { _ in
                    self.removeInfoContinuation(id: id)
                }
                addInfoContinuation(continuation, id: id)
                continuation.yield(activeApplication?.info)
            }
        }
    }

    func addInfoContinuation(
        _ continuation: AsyncStream<RunningApplicationInfo?>.Continuation,
        id: UUID
    ) {
        infoContinuations[id] = continuation
    }

    func removeInfoContinuation(id: UUID) {
        infoContinuations[id] = nil
    }

    private func notifyContinuations() {
        for continuation in infoContinuations {
            continuation.value.yield(activeApplication?.info)
        }
    }
}

public extension NSRunningApplication {
    var isXcode: Bool { bundleIdentifier == "com.apple.dt.Xcode" }
}

