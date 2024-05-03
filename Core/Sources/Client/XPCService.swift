import Foundation
import Logger
import os.log
import XPCShared

let shared = XPCExtensionService(logger: .client)

public func getService() throws -> XPCExtensionService {
    if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
        struct RunningInPreview: Error {}
        throw RunningInPreview()
    }
    return shared
}
