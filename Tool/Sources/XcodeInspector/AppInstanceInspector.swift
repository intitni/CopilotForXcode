import AppKit
import Foundation

public class AppInstanceInspector: ObservableObject {
    public var appElement: AXUIElement {
        AXUIElementCreateApplication(runningApplication.processIdentifier)
    }
    public let runningApplication: NSRunningApplication
    public var isActive: Bool { runningApplication.isActive }
    public var isXcode: Bool { runningApplication.isXcode }
    public var isExtensionService: Bool { runningApplication.isCopilotForXcodeExtensionService }

    init(runningApplication: NSRunningApplication) {
        self.runningApplication = runningApplication
    }
}

