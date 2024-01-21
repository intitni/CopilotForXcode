import AppKit
import Foundation

public class AppInstanceInspector: ObservableObject {
    public let appElement: AXUIElement
    public let runningApplication: NSRunningApplication
    public var isActive: Bool { runningApplication.isActive }
    public var isXcode: Bool { runningApplication.isXcode }
    public var isExtensionService: Bool { runningApplication.isCopilotForXcodeExtensionService }

    init(runningApplication: NSRunningApplication) {
        self.runningApplication = runningApplication
        appElement = AXUIElementCreateApplication(runningApplication.processIdentifier)
    }
}

