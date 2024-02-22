import AppKit
import Foundation

public class AppInstanceInspector: ObservableObject {
    let runningApplication: NSRunningApplication
    public let processIdentifier: pid_t
    public let bundleURL: URL?
    public let bundleIdentifier: String?

    public var appElement: AXUIElement {
        let app = AXUIElementCreateApplication(runningApplication.processIdentifier)
        app.setMessagingTimeout(2)
        return app
    }

    public var isTerminated: Bool {
        return runningApplication.isTerminated
    }

    public var isActive: Bool {
        guard !runningApplication.isTerminated else { return false }
        return runningApplication.isActive
    }

    public var isXcode: Bool {
        guard !runningApplication.isTerminated else { return false }
        return runningApplication.isXcode
    }

    public var isExtensionService: Bool {
        guard !runningApplication.isTerminated else { return false }
        return runningApplication.isCopilotForXcodeExtensionService
    }

    public func activate() -> Bool {
        return runningApplication.activate()
    }

    init(runningApplication: NSRunningApplication) {
        self.runningApplication = runningApplication
        processIdentifier = runningApplication.processIdentifier
        bundleURL = runningApplication.bundleURL
        bundleIdentifier = runningApplication.bundleIdentifier
    }
}

