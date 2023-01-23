import Foundation
import LaunchAgentManager

extension LaunchAgentManager {
    init() {
        self.init(
            serviceIdentifier: Bundle.main
                .object(forInfoDictionaryKey: "BUNDLE_IDENTIFIER_BASE") as! String +
                ".XPCService",
            executablePath: Bundle.main.executableURL?.deletingLastPathComponent()
                .appendingPathComponent("CopilotForXcodeXPCService").path ?? ""
        )
    }
}
