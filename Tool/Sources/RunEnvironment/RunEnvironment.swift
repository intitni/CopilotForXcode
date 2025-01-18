import Foundation

public enum RunEnvironment {
    public static var isTesting: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    public static var isPreview: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }

    public static var isDebug: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }
}
