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

    public func setupLaunchAgent() throws {
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
        launchctl("load", launchAgentPath)
    }

    public func removeLaunchAgent() throws {
        launchctl("unload", launchAgentPath)
        try FileManager.default.removeItem(atPath: launchAgentPath)
    }

    public func restartLaunchAgent() {
        launchctl("unload", launchAgentPath)
        launchctl("load", launchAgentPath)
    }
}

private func launchctl(_ args: String...) {
    let task = Process()
    task.launchPath = "/bin/launchctl"
    task.arguments = args
    task.environment = [
        "PATH": "/usr/bin",
    ]
    let outpipe = Pipe()
    task.standardOutput = outpipe
    try? task.run()
}
