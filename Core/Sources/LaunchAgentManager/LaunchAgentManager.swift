import Foundation
import ServiceManagement

public struct LaunchAgentManager {
    let lastLaunchAgentVersionKey = "LastLaunchAgentVersion"
    let serviceIdentifier: String
    let executableURL: URL
    let bundleIdentifier: String

    var launchAgentDirURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents")
    }

    var launchAgentPath: String {
        launchAgentDirURL.appendingPathComponent("\(serviceIdentifier).plist").path
    }

    public init(serviceIdentifier: String, executableURL: URL, bundleIdentifier: String) {
        self.serviceIdentifier = serviceIdentifier
        self.executableURL = executableURL
        self.bundleIdentifier = bundleIdentifier
    }

    public func setupLaunchAgentForTheFirstTimeIfNeeded() async throws {
        if #available(macOS 13, *) {
            try await setupLaunchAgent()
        } else {
            if UserDefaults.standard.integer(forKey: lastLaunchAgentVersionKey) < 40 {
                try await setupLaunchAgent()
                return
            }
            guard !FileManager.default.fileExists(atPath: launchAgentPath) else { return }
            try await setupLaunchAgent()
        }
    }

    public func setupLaunchAgent() async throws {
        if #available(macOS 13, *) {
            if executableURL.path.hasPrefix("/Applications") {
                try setupLaunchAgentWithPredefinedPlist()
            } else {
                try await setupLaunchAgentWithDynamicPlist()
            }
        } else {
            try await setupLaunchAgentWithDynamicPlist()
        }

        let buildNumber = (Bundle.main.infoDictionary?["CFBundleVersion"] as? String)
            .flatMap(Int.init)
        UserDefaults.standard.set(buildNumber, forKey: lastLaunchAgentVersionKey)
    }

    public func removeLaunchAgent() async throws {
        if #available(macOS 13, *) {
            let bridgeLaunchAgent = SMAppService.agent(plistName: "bridgeLaunchAgent.plist")
            try? await bridgeLaunchAgent.unregister()
            if FileManager.default.fileExists(atPath: launchAgentPath) {
                try? await launchctl("unload", launchAgentPath)
                try? FileManager.default.removeItem(atPath: launchAgentPath)
            }
        } else {
            try await launchctl("unload", launchAgentPath)
            try FileManager.default.removeItem(atPath: launchAgentPath)
        }
    }

    public func reloadLaunchAgent() async throws {
        if #unavailable(macOS 13) {
            try await helper("reload-launch-agent", "--service-identifier", serviceIdentifier)
        }
    }
}

extension LaunchAgentManager {
    @available(macOS 13, *)
    func setupLaunchAgentWithPredefinedPlist() throws {
        let bridgeLaunchAgent = SMAppService.agent(plistName: "bridgeLaunchAgent.plist")
        try bridgeLaunchAgent.register()
    }
    
    func setupLaunchAgentWithDynamicPlist() async throws {
        if FileManager.default.fileExists(atPath: launchAgentPath) {
            throw E(errorDescription: "Launch agent already exists.")
        }
        
        let content = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>\(serviceIdentifier)</string>
            <key>Program</key>
            <string>\(executableURL.path)</string>
            <key>MachServices</key>
            <dict>
                <key>\(serviceIdentifier)</key>
                <true/>
            </dict>
            <key>AssociatedBundleIdentifiers</key>
            <array>
                <string>\(bundleIdentifier)</string>
                <string>\(serviceIdentifier)</string>
            </array>
        </dict>
        </plist>
        """
        if !FileManager.default.fileExists(atPath: launchAgentDirURL.path) {
            try FileManager.default.createDirectory(
                at: launchAgentDirURL,
                withIntermediateDirectories: false
            )
        }
        FileManager.default.createFile(
            atPath: launchAgentPath,
            contents: content.data(using: .utf8)
        )
        #if DEBUG
        #else
        try await launchctl("load", launchAgentPath)
        #endif
    }
}

private func process(_ launchPath: String, _ args: [String]) async throws {
    let task = Process()
    task.launchPath = launchPath
    task.arguments = args
    task.environment = [
        "PATH": "/usr/bin",
    ]
    let outpipe = Pipe()
    task.standardOutput = outpipe

    return try await withUnsafeThrowingContinuation { continuation in
        do {
            task.terminationHandler = { process in
                do {
                    if process.terminationStatus == 0 {
                        continuation.resume(returning: ())
                    } else {
                        if let data = try? outpipe.fileHandleForReading.readToEnd(),
                           let content = String(data: data, encoding: .utf8)
                        {
                            continuation.resume(throwing: E(errorDescription: content))
                        } else {
                            continuation.resume(
                                throwing: E(
                                    errorDescription: "Unknown error."
                                )
                            )
                        }
                    }
                }
            }
            try task.run()
        } catch {
            continuation.resume(throwing: error)
        }
    }
}

private func helper(_ args: String...) async throws {
    // TODO: A more robust way to locate the executable.
    guard let url = Bundle.main.executableURL?
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("Applications")
        .appendingPathComponent("Helper")
    else { throw E(errorDescription: "Unable to locate Helper.") }
    return try await process(url.path, args)
}

private func launchctl(_ args: String...) async throws {
    return try await process("/bin/launchctl", args)
}

private struct E: Error, LocalizedError {
    var errorDescription: String?
}

