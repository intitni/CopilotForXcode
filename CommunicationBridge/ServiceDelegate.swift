import AppKit
import Foundation
import Logger
import XPCShared

class ServiceDelegate: NSObject, NSXPCListenerDelegate {
    func listener(
        _: NSXPCListener,
        shouldAcceptNewConnection newConnection: NSXPCConnection
    ) -> Bool {
        guard let teamID = XPCPeerRequirement.teamID(fromPrefix: teamIDPrefix) else {
            Logger.communicationBridge.error(
                "Rejected XPC connection from pid \(newConnection.processIdentifier): Team ID is unavailable."
            )
            return false
        }
        let requirement = XPCPeerRequirement.codeSigningRequirement(teamID: teamID)
        do {
            try XPCPeerRequirement.setCodeSigningRequirement(on: newConnection, teamID: teamID)
        } catch {
            Logger.communicationBridge.error(
                "Rejected XPC connection from pid \(newConnection.processIdentifier): invalid code signing requirement (\(requirement))."
            )
            return false
        }

        newConnection.exportedInterface = NSXPCInterface(
            with: CommunicationBridgeXPCServiceProtocol.self
        )

        let exportedObject = XPCService(processIdentifier: newConnection.processIdentifier)
        newConnection.exportedObject = exportedObject
        newConnection.resume()

        Logger.communicationBridge.info("Accepted new connection.")

        return true
    }
}

class XPCService: CommunicationBridgeXPCServiceProtocol {
    static let eventHandler = EventHandler()
    let processIdentifier: pid_t

    init(processIdentifier: pid_t) {
        self.processIdentifier = processIdentifier
    }

    func launchExtensionServiceIfNeeded(
        withReply reply: @escaping (NSXPCListenerEndpoint?) -> Void
    ) {
        Task {
            await Self.eventHandler.launchExtensionServiceIfNeeded(withReply: reply)
        }
    }

    func quit(withReply reply: @escaping () -> Void) {
        Task {
            await Self.eventHandler.quit(withReply: reply)
        }
    }

    func updateServiceEndpoint(
        endpoint: NSXPCListenerEndpoint,
        withReply reply: @escaping () -> Void
    ) {
        Task {
            await Self.eventHandler.updateServiceEndpoint(
                endpoint: endpoint,
                processIdentifier: processIdentifier,
                withReply: reply
            )
        }
    }
}

actor EventHandler {
    var endpoint: NSXPCListenerEndpoint?
    var endpointPID: pid_t?
    let launcher = ExtensionServiceLauncher()
    var exitTask: Task<Void, Error>?

    init() {
        Task { await rescheduleExitTask() }
    }

    func launchExtensionServiceIfNeeded(
        withReply reply: @escaping (NSXPCListenerEndpoint?) -> Void
    ) async {
        rescheduleExitTask()
        if let endpoint,
           let pid = endpointPID,
           let running = NSRunningApplication(processIdentifier: pid),
           !running.isTerminated
        {
            Logger.communicationBridge.info("Service app is still valid")
            await launcher.attach(running)
            reply(endpoint)
            return
        }
        // Stale anonymous listener: do not keep a handle just because some other
        // process with the same bundle id is still running.
        endpoint = nil
        endpointPID = nil
        if await launcher.isApplicationValid {
            Logger.communicationBridge.info("Service app is still valid")
            reply(nil)
        } else {
            await launcher.launch()
            reply(nil)
        }
    }

    func quit(withReply reply: () -> Void) {
        Logger.communicationBridge.info("Exiting service.")
        listener.invalidate()
        exit(0)
    }

    func updateServiceEndpoint(
        endpoint: NSXPCListenerEndpoint,
        processIdentifier: pid_t,
        withReply reply: () -> Void
    ) {
        rescheduleExitTask()
        let expectedBundleID = bundleIdentifierBase + ".ExtensionService"
        let actualBundleID = NSRunningApplication(processIdentifier: processIdentifier)?
            .bundleIdentifier
        guard actualBundleID == expectedBundleID else {
            Logger.communicationBridge.error(
                "Ignoring service endpoint from pid \(processIdentifier) (\(actualBundleID ?? "unknown bundle id")); expected \(expectedBundleID)."
            )
            reply()
            return
        }
        self.endpoint = endpoint
        endpointPID = processIdentifier
        reply()
    }

    /// The bridge will kill itself when it's not used for a period.
    /// It's fine that the bridge is killed because it will be launched again when needed.
    private func rescheduleExitTask() {
        exitTask?.cancel()
        exitTask = Task {
            #if DEBUG
            try await Task.sleep(nanoseconds: 60_000_000_000)
            Logger.communicationBridge.info("Exit will be called in release build.")
            #else
            try await Task.sleep(nanoseconds: 1_800_000_000_000)
            Logger.communicationBridge.info("Exiting service.")
            listener.invalidate()
            exit(0)
            #endif
        }
    }
}

actor ExtensionServiceLauncher {
    let appIdentifier = bundleIdentifierBase.appending(".ExtensionService")
    let appURL = Bundle.main.bundleURL.appendingPathComponent(
        "CopilotForXcodeExtensionService.app"
    )
    var isLaunching: Bool = false
    var application: NSRunningApplication?
    var isApplicationValid: Bool {
        guard let application else { return false }
        if application.isTerminated { return false }
        let identifier = application.processIdentifier
        if let application = NSWorkspace.shared.runningApplications.first(where: {
            $0.processIdentifier == identifier
        }) {
            Logger.communicationBridge.info(
                "Service app found: \(application.processIdentifier) \(String(describing: application.bundleIdentifier))"
            )
            return true
        }
        return false
    }

    func attach(_ application: NSRunningApplication) {
        self.application = application
    }

    func launch() {
        if let running = runningApplicationMatchingAppURL() {
            application = running
            return
        }

        guard !isLaunching else { return }
        isLaunching = true

        Logger.communicationBridge.info("Launching extension service app.")

        NSWorkspace.shared.openApplication(
            at: appURL,
            configuration: {
                let configuration = NSWorkspace.OpenConfiguration()
                configuration.createsNewApplicationInstance = false
                configuration.addsToRecentItems = false
                configuration.activates = false
                return configuration
            }()
        ) { app, error in
            if let error = error {
                Logger.communicationBridge.error(
                    "Failed to launch extension service app: \(error)"
                )
            } else {
                Logger.communicationBridge.info(
                    "Finished launching extension service app."
                )
            }

            self.application = app
            self.isLaunching = false
        }
    }

    /// Prefer the instance launched from this package; other installs with the same
    /// bundle id fall through to `openApplication(at: appURL)`.
    private func runningApplicationMatchingAppURL() -> NSRunningApplication? {
        let wanted = appURL.standardizedFileURL
        return NSRunningApplication.runningApplications(withBundleIdentifier: appIdentifier)
            .first { running in
                guard !running.isTerminated else { return false }
                guard let bundleURL = running.bundleURL else { return false }
                return bundleURL.standardizedFileURL == wanted
            }
    }
}
