import Foundation

public struct LaunchAgentManager {
    let serviceIdentifier: String
    let executablePath: String

    var launchAgentDirURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents")
    }

    var launchAgentPath: String {
        launchAgentDirURL.appendingPathComponent("\(serviceIdentifier).plist").path
    }

    public init(serviceIdentifier: String, executablePath: String) {
        self.serviceIdentifier = serviceIdentifier
        self.executablePath = executablePath
    }

    public func setupLaunchAgent() async throws {
        let content = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>RunAtLoad</key>
                <true/>
            <key>Label</key>
                <string>\(serviceIdentifier)</string>
                <key>Program</key>
                <string>\(executablePath)</string>
            <key>MachServices</key>
            <dict>
                <key>\(serviceIdentifier)</key>
                <true/>
            </dict>
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
        try await launchctl("load", launchAgentPath)
    }

    public func removeLaunchAgent() async throws {
        try await launchctl("unload", launchAgentPath)
        try FileManager.default.removeItem(atPath: launchAgentPath)
    }

    public func restartLaunchAgent() async throws {
        try await helper("reload-launch-agent", "--service-identifier", serviceIdentifier)
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
    guard let url = Bundle.main.executableURL?
        .deletingLastPathComponent()
        .appendingPathComponent("Helper")
    else { throw E(errorDescription: "Unable to locate Helper.") }
    return try await process(url.path, args)
}

private func launchctl(_ args: String...) async throws {
    return try await process("/bin/launchctl", args)
}

struct E: Error, LocalizedError {
    var errorDescription: String?
}
