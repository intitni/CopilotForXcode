import AppKit
import Foundation

public extension NSRunningApplication {
    var isXcode: Bool { bundleIdentifier == "com.apple.dt.Xcode" }
    var isCopilotForXcodeExtensionService: Bool {
        bundleIdentifier == Bundle.main.bundleIdentifier
    }
}

public extension FileManager {
    func fileIsDirectory(atPath path: String) -> Bool {
        var isDirectory: ObjCBool = false
        let exists = fileExists(atPath: path, isDirectory: &isDirectory)
        return isDirectory.boolValue && exists
    }
}

