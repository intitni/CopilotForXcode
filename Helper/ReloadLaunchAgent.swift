import ArgumentParser
import Foundation

struct ReloadLaunchAgent: ParsableCommand {
    static var configuration = CommandConfiguration(
        abstract: "Reload the launch agent"
    )

    @Option(name: .long, help: "The service identifier of the service.")
    var serviceIdentifier: String

    var launchAgentDirURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents")
    }

    var launchAgentPath: String {
        launchAgentDirURL.appendingPathComponent("\(serviceIdentifier).plist").path
    }

    func run() throws {
        try? launchctl("unload", launchAgentPath)
        try launchctl("load", launchAgentPath)
    }
}

private func launchctl(_ args: String...) throws {
    return try process("/bin/launchctl", args)
}

private func process(_ launchPath: String, _ args: [String]) throws {
    let task = Process()
    task.launchPath = launchPath
    task.arguments = args
    task.environment = [
        "PATH": "/usr/bin",
    ]
    let outpipe = Pipe()
    task.standardOutput = outpipe
    try task.run()
    task.waitUntilExit()

    struct E: Error, LocalizedError {
        var errorDescription: String?
    }

    if task.terminationStatus == 0 {
        return
    }
    throw E(
        errorDescription: "Failed to restart. Please make sure the launch agent is already loaded."
    )
}
