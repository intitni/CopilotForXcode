import AppKit
import FileChangeChecker
import Foundation
import LaunchAgentManager
import os.log
import Service

let bundleIdentifierBase = Bundle.main
    .object(forInfoDictionaryKey: "BUNDLE_IDENTIFIER_BASE") as! String

let serviceIdentifier = bundleIdentifierBase + ".XPCService"

func setupXPCListener() -> (NSXPCListener, ServiceDelegate) {
    let listener = NSXPCListener(machServiceName: serviceIdentifier)
    let delegate = ServiceDelegate()
    listener.delegate = delegate
    listener.resume()
    return (listener, delegate)
}

func setupAutoTrigger() {
    _ = AutoTrigger.shared
}

func setupRestartOnUpdate() {
    Task {
        guard let url = Bundle.main.executableURL else { return }
        let checker = await FileChangeChecker(fileURL: url)

        // If Xcode or Copilot for Xcode is made active, check if the executable of this program is
        // changed.
        // If changed, restart the launch agent.

        let sequence = NSWorkspace.shared.notificationCenter
            .notifications(named: NSWorkspace.didActivateApplicationNotification)
        for await notification in sequence {
            try Task.checkCancellation()
            guard let app = notification
                .userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                [
                    "com.apple.dt.Xcode",
                    bundleIdentifierBase,
                ].contains(app.bundleIdentifier)
            else { continue }
            guard await checker.checkIfChanged() else {
                os_log(.info, "XPC Service is not updated, no need to restart.")
                continue
            }
            os_log(.info, "XPC Service will be restarted.")
            #if DEBUG
            #else
            let manager = LaunchAgentManager(
                serviceIdentifier: serviceIdentifier,
                executablePath: Bundle.main.executablePath ?? ""
            )
            do {
                try await manager.restartLaunchAgent()
            } catch {
                os_log(
                    .error,
                    "XPC Service failed to restart. %{public}s",
                    error.localizedDescription
                )
            }
            #endif
        }
    }
}

let xpcListener = setupXPCListener()
setupAutoTrigger()
setupRestartOnUpdate()
os_log(.info, "XPC Service started.")
RunLoop.main.run()
