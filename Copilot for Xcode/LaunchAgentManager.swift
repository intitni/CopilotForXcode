import Foundation

struct LaunchAgentManager {
    var serviceIdentifier: String {
        Bundle.main
            .object(forInfoDictionaryKey: "BUNDLE_IDENTIFIER_BASE") as! String +
            ".XPCService"
    }

    var location: String {
        Bundle.main.executableURL?.deletingLastPathComponent()
            .appendingPathComponent("CopilotForXcodeXPCService").path ?? ""
    }

    var launchAgentDirURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents")
    }

    var launchAgentPath: String {
        launchAgentDirURL.appendingPathComponent("\(serviceIdentifier).plist").path
    }

    func setupLaunchAgent() throws {
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
                <string>\(location)</string>
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

    func removeLaunchAgent() throws {
        launchctl("unload", launchAgentPath)
        try FileManager.default.removeItem(atPath: launchAgentPath)
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
    task.waitUntilExit()
    if let data = try? outpipe.fileHandleForReading.readToEnd(),
       let text = String(data: data, encoding: .utf8)
    {
        print(text)
    }
}
