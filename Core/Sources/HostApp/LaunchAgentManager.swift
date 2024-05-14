import Foundation
import LaunchAgentManager

extension LaunchAgentManager {
    init() {
        self.init(
            serviceIdentifier: Bundle.main
                .object(forInfoDictionaryKey: "BUNDLE_IDENTIFIER_BASE") as! String +
                ".CommunicationBridge",
            executablePath: Bundle.main.bundleURL
                .appendingPathComponent("Contents")
                .appendingPathComponent("Applications")
                .appendingPathComponent("CommunicationBridge")
                .path,
            bundleIdentifier: Bundle.main
                .object(forInfoDictionaryKey: "BUNDLE_IDENTIFIER_BASE") as! String
        )
    }
}

