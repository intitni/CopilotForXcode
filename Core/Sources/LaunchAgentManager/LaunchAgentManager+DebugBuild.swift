#if DEBUG
import Foundation
import os

/// Debug builds run straight from DerivedData, so the release flow (`SMAppService` with the
/// plist bundled for /Applications) can't be used. Upstream expects developers to run every
/// target from Xcode by hand; this fork instead registers the bridge automatically so a plain
/// "Run" of the host app brings the whole service chain up.
extension LaunchAgentManager {
    private static let logger = os.Logger(
        subsystem: "com.intii.CopilotForXcode",
        category: "LaunchAgentManager"
    )

    /// Modification date of the bridge executable the last time launchd (re)started it.
    private static let bridgeModificationDateKey = "DebugBuild.LaunchAgentBridgeModificationDate"

    /// Idempotent, safe to call on every launch:
    /// 1. writes `~/Library/LaunchAgents/<serviceIdentifier>.plist`, replacing it when the
    ///    executable path changed (for example a new DerivedData location);
    /// 2. bootstraps it into the user's launchd domain when it isn't loaded;
    /// 3. restarts the bridge when its binary was rebuilt since the last restart, so the freshly
    ///    built code is the one serving XPC requests.
    public func setupLaunchAgentForDebugBuild() async throws {
        let plist = debugPlistContent
        let existing = try? String(contentsOfFile: launchAgentPath, encoding: .utf8)
        let isLoaded = await isDebugLaunchAgentLoaded()
        let bridgeModificationDate = try? FileManager.default
            .attributesOfItem(atPath: executableURL.path)[.modificationDate] as? Date
        let defaults = UserDefaults.standard
        let lastBridgeModificationDate = defaults
            .object(forKey: Self.bridgeModificationDateKey) as? Date

        if existing != plist {
            if isLoaded {
                try await debugLaunchctl("bootout", serviceTarget)
                await waitUntilDebugLaunchAgentUnloaded()
            }
            try writeDebugPlist(plist)
            try await debugLaunchctl("bootstrap", domainTarget, launchAgentPath)
            Self.logger.info(
                "Registered \(serviceIdentifier, privacy: .public) -> \(executableURL.path, privacy: .public)"
            )
        } else if !isLoaded {
            try await debugLaunchctl("bootstrap", domainTarget, launchAgentPath)
            Self.logger.info("Bootstrapped \(serviceIdentifier, privacy: .public)")
        } else if let bridgeModificationDate, bridgeModificationDate != lastBridgeModificationDate {
            try await debugLaunchctl("kickstart", "-k", serviceTarget)
            Self.logger.info("Restarted the bridge because its executable was rebuilt")
        }

        defaults.set(bridgeModificationDate, forKey: Self.bridgeModificationDateKey)
    }
}

private extension LaunchAgentManager {
    var domainTarget: String { "gui/\(getuid())" }
    var serviceTarget: String { "\(domainTarget)/\(serviceIdentifier)" }

    /// Same template as `setupLaunchAgentWithDynamicPlist`, kept here so the release code path
    /// stays byte-for-byte upstream.
    var debugPlistContent: String {
        """
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
    }

    func writeDebugPlist(_ content: String) throws {
        try FileManager.default.createDirectory(
            at: launchAgentDirURL,
            withIntermediateDirectories: true
        )
        try content.write(toFile: launchAgentPath, atomically: true, encoding: .utf8)
    }

    func isDebugLaunchAgentLoaded() async -> Bool {
        (try? await debugLaunchctl("print", serviceTarget)) != nil
    }

    func waitUntilDebugLaunchAgentUnloaded() async {
        for _ in 0..<20 {
            if await !isDebugLaunchAgentLoaded() { return }
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
    }

    @discardableResult
    func debugLaunchctl(_ arguments: String...) async throws -> String {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        task.arguments = arguments
        task.environment = ["PATH": "/usr/bin:/bin"]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe

        return try await withCheckedThrowingContinuation { continuation in
            task.terminationHandler = { process in
                let data = (try? pipe.fileHandleForReading.readToEnd()) ?? Data()
                let output = String(data: data, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if process.terminationStatus == 0 {
                    continuation.resume(returning: output)
                } else {
                    continuation.resume(throwing: DebugLaunchAgentError(
                        command: "launchctl " + arguments.joined(separator: " "),
                        status: process.terminationStatus,
                        output: output
                    ))
                }
            }
            do {
                try task.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}

private struct DebugLaunchAgentError: Error, LocalizedError {
    let command: String
    let status: Int32
    let output: String

    var errorDescription: String? {
        var message = "\(command) failed (\(status))"
        if !output.isEmpty { message += ": \(output)" }
        if output.contains("Input/output error") || status == 5 {
            message += ". If the login item was disabled, enable it in System Settings › General › Login Items & Extensions."
        }
        return message
    }
}
#endif
